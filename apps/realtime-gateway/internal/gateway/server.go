package gateway

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
)

const commandRateScript = `
local count = redis.call('INCR', KEYS[1])
if count == 1 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end
return count
`

type Server struct {
	Config     Config
	Auth       Authorizer
	Redis      *redis.Client
	Hub        *Hub
	Logger     *slog.Logger
	subscribed atomic.Bool
	authSlots  chan struct{}
}

func NewServer(cfg Config, auth Authorizer, client *redis.Client, logger *slog.Logger) *Server {
	return &Server{Config: cfg, Auth: auth, Redis: client, Hub: NewHub(), Logger: logger, authSlots: make(chan struct{}, 512)}
}

func (s *Server) verify(ctx context.Context, token, action, roomID string) (Principal, error) {
	select {
	case s.authSlots <- struct{}{}:
		defer func() { <-s.authSlots }()
		return s.Auth.Verify(ctx, token, action, roomID)
	case <-ctx.Done():
		return Principal{}, ctx.Err()
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /live", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"live"}`))
	})
	mux.HandleFunc("GET /ready", s.ready)
	mux.HandleFunc("GET /metrics", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(s.Hub.Metrics()))
		if s.subscribed.Load() {
			_, _ = w.Write([]byte("funkey_realtime_redis_subscription_up 1\n"))
		} else {
			_, _ = w.Write([]byte("funkey_realtime_redis_subscription_up 0\n"))
		}
	})
	mux.HandleFunc("GET /ws", s.serveWS)
	return mux
}

func (s *Server) ready(w http.ResponseWriter, r *http.Request) {
	if s.Hub.IsDraining() || !s.subscribed.Load() {
		http.Error(w, "not ready", http.StatusServiceUnavailable)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), time.Second)
	defer cancel()
	if err := s.Redis.Ping(ctx).Err(); err != nil {
		http.Error(w, "not ready", http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write([]byte(`{"status":"ready"}`))
}

func bearerToken(r *http.Request) string {
	if value := r.Header.Get("Authorization"); strings.HasPrefix(value, "Bearer ") {
		return strings.TrimSpace(strings.TrimPrefix(value, "Bearer "))
	}
	// Browser WebSocket APIs cannot set Authorization. The token is accepted as
	// a subprotocol value but never echoed as the selected subprotocol.
	for _, protocol := range websocket.Subprotocols(r) {
		if strings.HasPrefix(protocol, "bearer.") {
			return strings.TrimPrefix(protocol, "bearer.")
		}
	}
	return ""
}

func newID() string {
	var bytes [16]byte
	if _, err := rand.Read(bytes[:]); err != nil {
		panic(err)
	}
	return hex.EncodeToString(bytes[:])
}

func (s *Server) serveWS(w http.ResponseWriter, r *http.Request) {
	if s.Hub.IsDraining() {
		http.Error(w, "draining", http.StatusServiceUnavailable)
		return
	}
	origin := r.Header.Get("Origin")
	if origin != "" {
		if _, allowed := s.Config.Origins[origin]; !allowed {
			http.Error(w, "origin denied", http.StatusForbidden)
			return
		}
	}
	token := bearerToken(r)
	if token == "" {
		s.Hub.stats.AuthDenied.Add(1)
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), s.Config.AuthTimeout)
	principal, err := s.verify(ctx, token, "connect", "")
	cancel()
	if err != nil {
		s.Hub.stats.AuthDenied.Add(1)
		status := http.StatusServiceUnavailable
		if errors.Is(err, ErrUnauthorized) {
			status = http.StatusUnauthorized
		}
		http.Error(w, "connection denied", status)
		return
	}
	ctx, cancel = context.WithTimeout(r.Context(), time.Second)
	err = s.Redis.Ping(ctx).Err()
	cancel()
	if err != nil || !s.subscribed.Load() {
		http.Error(w, "gateway unavailable", http.StatusServiceUnavailable)
		return
	}
	upgrader := websocket.Upgrader{
		Subprotocols: []string{"funkey.v1"},
		CheckOrigin:  func(_ *http.Request) bool { return true }, // checked above
	}
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	client := newClient(newID(), principal.UserID, token, conn, s.Config.OutboundQueue)
	if !s.Hub.Add(client, s.Config.MaxConnections) {
		_ = conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseTryAgainLater, "capacity"), time.Now().Add(time.Second))
		_ = conn.Close()
		return
	}
	s.touchClient(client)
	s.Hub.Enqueue(client, []byte(`{"type":"connected","version":1}`))
	go s.writePump(client)
	s.readPump(client)
	s.Hub.Remove(client)
	s.deleteClientLease(client)
}

type clientCommand struct {
	Type         string `json:"type"`
	RoomPublicID string `json:"room_public_id"`
}

func validRoomID(roomID string) bool {
	if roomID == "" || len(roomID) > 32 {
		return false
	}
	for _, ch := range roomID {
		if !((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
			(ch >= '0' && ch <= '9') || ch == '_' || ch == '-') {
			return false
		}
	}
	return true
}

func (s *Server) readPump(c *Client) {
	defer s.Hub.Remove(c)
	c.Conn.SetReadLimit(s.Config.MaxMessageBytes)
	_ = c.Conn.SetReadDeadline(time.Now().Add(s.Config.PongTimeout))
	c.Conn.SetPongHandler(func(string) error {
		return c.Conn.SetReadDeadline(time.Now().Add(s.Config.PongTimeout))
	})
	window := time.Now()
	count := 0
	for {
		_, payload, err := c.Conn.ReadMessage()
		if err != nil {
			return
		}
		if time.Since(window) >= time.Second {
			window, count = time.Now(), 0
		}
		count++
		if count > 25 {
			_ = c.Conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "rate limit"), time.Now().Add(time.Second))
			return
		}
		rateCtx, rateCancel := context.WithTimeout(context.Background(), time.Second)
		rateKey := "funkey:realtime:gateway:rate:" + strconv.FormatInt(c.UserID, 10)
		total, rateErr := s.Redis.Eval(rateCtx, commandRateScript, []string{rateKey}, 1000).Int64()
		rateCancel()
		if rateErr != nil || total > 60 {
			_ = c.Conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "distributed rate limit"), time.Now().Add(time.Second))
			return
		}
		var command clientCommand
		if err := json.Unmarshal(payload, &command); err != nil {
			s.Hub.Enqueue(c, []byte(`{"type":"error","code":"invalid_message"}`))
			continue
		}
		switch command.Type {
		case "ping":
			s.Hub.Enqueue(c, []byte(`{"type":"pong"}`))
		case "subscribe":
			if !validRoomID(command.RoomPublicID) {
				s.Hub.Enqueue(c, []byte(`{"type":"error","code":"invalid_room"}`))
				continue
			}
			ctx, cancel := context.WithTimeout(context.Background(), s.Config.AuthTimeout)
			principal, err := s.verify(ctx, c.Token, "subscribe", command.RoomPublicID)
			cancel()
			if err != nil || principal.UserID != c.UserID {
				s.Hub.stats.AuthDenied.Add(1)
				s.Hub.Enqueue(c, []byte(`{"type":"error","code":"subscribe_denied"}`))
				continue
			}
			if !s.Hub.Subscribe(c, command.RoomPublicID) {
				s.Hub.Enqueue(c, []byte(`{"type":"error","code":"subscription_limit"}`))
				continue
			}
			ack, _ := json.Marshal(map[string]string{"type": "subscribed", "room_public_id": command.RoomPublicID})
			s.Hub.Enqueue(c, ack)
		case "unsubscribe":
			s.Hub.Unsubscribe(c, command.RoomPublicID)
		default:
			s.Hub.Enqueue(c, []byte(`{"type":"error","code":"unsupported_command"}`))
		}
	}
}

func (s *Server) writePump(c *Client) {
	ticker := time.NewTicker(s.Config.PingInterval)
	defer ticker.Stop()
	reauth := time.NewTicker(s.Config.ReauthInterval)
	defer reauth.Stop()
	defer s.Hub.Remove(c)
	for {
		select {
		case <-c.done:
			return
		case payload := <-c.send:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(s.Config.WriteTimeout))
			if err := c.Conn.WriteMessage(websocket.TextMessage, payload); err != nil {
				return
			}
		case <-ticker.C:
			if err := c.Conn.WriteControl(websocket.PingMessage, nil, time.Now().Add(s.Config.WriteTimeout)); err != nil {
				return
			}
		case <-reauth.C:
			ctx, cancel := context.WithTimeout(context.Background(), s.Config.AuthTimeout)
			principal, err := s.verify(ctx, c.Token, "connect", "")
			cancel()
			if err != nil || principal.UserID != c.UserID {
				s.Hub.stats.AuthDenied.Add(1)
				_ = c.Conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "reauthorization failed"), time.Now().Add(time.Second))
				return
			}
			for _, roomID := range s.Hub.Rooms(c) {
				ctx, cancel := context.WithTimeout(context.Background(), s.Config.AuthTimeout)
				principal, err := s.verify(ctx, c.Token, "subscribe", roomID)
				cancel()
				if err != nil || principal.UserID != c.UserID {
					s.Hub.Unsubscribe(c, roomID)
					notice, _ := json.Marshal(map[string]string{"type": "subscription_revoked", "room_public_id": roomID})
					s.Hub.Enqueue(c, notice)
				}
			}
		}
	}
}

func (s *Server) touchClient(c *Client) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	key := "funkey:realtime:gateway:user:" + strconv.FormatInt(c.UserID, 10) + ":" + c.ID
	_ = s.Redis.Set(ctx, key, s.Config.NodeID, s.Config.LeaseTTL).Err()
}

func (s *Server) deleteClientLease(c *Client) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	key := "funkey:realtime:gateway:user:" + strconv.FormatInt(c.UserID, 10) + ":" + c.ID
	_ = s.Redis.Del(ctx, key).Err()
}

func (s *Server) Heartbeat(ctx context.Context) {
	ticker := time.NewTicker(s.Config.LeaseTTL / 3)
	defer ticker.Stop()
	for {
		s.heartbeatOnce(ctx)
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}

func (s *Server) heartbeatOnce(ctx context.Context) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	clients := s.Hub.Clients()
	state := "ready"
	if s.Hub.IsDraining() {
		state = "draining"
	}
	body, _ := json.Marshal(map[string]any{
		"node_id": s.Config.NodeID, "state": state, "connections": len(clients),
	})
	pipe := s.Redis.Pipeline()
	pipe.Set(ctx, "funkey:realtime:gateway:node:"+s.Config.NodeID, body, s.Config.LeaseTTL)
	for _, c := range clients {
		key := "funkey:realtime:gateway:user:" + strconv.FormatInt(c.UserID, 10) + ":" + c.ID
		pipe.Set(ctx, key, s.Config.NodeID, s.Config.LeaseTTL)
	}
	if _, err := pipe.Exec(ctx); err != nil {
		s.Logger.Warn("redis heartbeat failed", "error", err)
	}
}

func (s *Server) ConsumeEvents(ctx context.Context) {
	interrupted := false
	for ctx.Err() == nil {
		pubsub := s.Redis.Subscribe(ctx, EventChannel)
		if _, err := pubsub.Receive(ctx); err != nil {
			_ = pubsub.Close()
			s.subscribed.Store(false)
			interrupted = true
			s.Logger.Warn("redis subscription failed", "error", err)
			if !waitRetry(ctx, time.Second) {
				return
			}
			continue
		}
		s.subscribed.Store(true)
		if interrupted {
			for _, client := range s.Hub.Clients() {
				if !s.Hub.Enqueue(client, []byte(`{"type":"resync_required"}`)) {
					s.Hub.Remove(client)
				}
			}
			interrupted = false
		}
		for ctx.Err() == nil {
			msg, err := pubsub.ReceiveMessage(ctx)
			if err != nil {
				s.Logger.Warn("redis event stream interrupted", "error", err)
				interrupted = true
				break
			}
			if len(msg.Payload) > 64*1024 {
				s.Hub.stats.InvalidEvents.Add(1)
				continue
			}
			var event Event
			if err := json.Unmarshal([]byte(msg.Payload), &event); err != nil {
				s.Hub.stats.InvalidEvents.Add(1)
				continue
			}
			s.Hub.Publish(event, []byte(msg.Payload))
		}
		s.subscribed.Store(false)
		_ = pubsub.Close()
		if !waitRetry(ctx, time.Second) {
			return
		}
	}
}

func waitRetry(ctx context.Context, delay time.Duration) bool {
	timer := time.NewTimer(delay)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-timer.C:
		return true
	}
}

func (s *Server) Drain(ctx context.Context) {
	deadline := time.Now().Add(s.Config.DrainTimeout)
	s.Hub.Drain(deadline)
	s.heartbeatOnce(ctx)
	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()
	for s.Hub.stats.Connections.Load() > 0 && time.Now().Before(deadline) {
		select {
		case <-ctx.Done():
			s.Hub.CloseAll()
			return
		case <-ticker.C:
		}
	}
	s.Hub.CloseAll()
}

func (s *Server) DeleteNodeLease(ctx context.Context) {
	ctx, cancel := context.WithTimeout(ctx, time.Second)
	defer cancel()
	_ = s.Redis.Del(ctx, "funkey:realtime:gateway:node:"+s.Config.NodeID).Err()
}

func (s *Server) Validate() error {
	if s.Auth == nil || s.Redis == nil || s.Hub == nil {
		return fmt.Errorf("gateway dependencies are required")
	}
	return nil
}

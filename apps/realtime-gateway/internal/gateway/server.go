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
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/trace"
)

const commandRateScript = `
local count = redis.call('INCR', KEYS[1])
if count == 1 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end
return count
`

type Server struct {
	Config       Config
	Auth         Authorizer
	Commands     CommandExecutor
	Redis        *redis.Client
	Hub          *Hub
	Logger       *slog.Logger
	subscribed   atomic.Bool
	authSlots    chan struct{}
	commandSlots chan struct{}
}

func NewServer(
	cfg Config,
	auth Authorizer,
	commands CommandExecutor,
	client *redis.Client,
	logger *slog.Logger,
) *Server {
	return &Server{
		Config: cfg, Auth: auth, Commands: commands, Redis: client,
		Hub: NewHub(), Logger: logger,
		authSlots: make(chan struct{}, 512),
		commandSlots: make(chan struct{}, 256),
	}
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
	return otelhttp.NewHandler(
		mux,
		"realtime.http",
		otelhttp.WithFilter(func(r *http.Request) bool {
			switch r.URL.Path {
			case "/ws", "/live", "/ready", "/metrics":
				return false
			default:
				return true
			}
		}),
	)
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
	traceContext := otel.GetTextMapPropagator().Extract(
		r.Context(),
		propagation.HeaderCarrier(r.Header),
	)
	traceContext, connectSpan := otel.Tracer("funkey.realtime").Start(
		traceContext,
		"realtime.connect",
		trace.WithSpanKind(trace.SpanKindServer),
	)
	spanEnded := false
	defer func() {
		if !spanEnded {
			connectSpan.End()
		}
	}()
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
	ctx, cancel := context.WithTimeout(traceContext, s.Config.AuthTimeout)
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
	ctx, cancel = context.WithTimeout(traceContext, time.Second)
	err = s.Redis.Ping(ctx).Err()
	cancel()
	if err != nil || !s.subscribed.Load() {
		http.Error(w, "gateway unavailable", http.StatusServiceUnavailable)
		return
	}
	upgrader := websocket.Upgrader{
		Subprotocols: []string{"funkey.v2", "funkey.v1"},
		CheckOrigin:  func(_ *http.Request) bool { return true }, // checked above
	}
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	client := newClient(
		newID(),
		principal.UserID,
		principal.IsStaff,
		token,
		conn,
		s.Config.OutboundQueue,
	)
	if !s.Hub.Add(client, s.Config.MaxConnections, s.Config.MaxConnectionsPerUser) {
		_ = conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseTryAgainLater, "capacity"), time.Now().Add(time.Second))
		_ = conn.Close()
		return
	}
	s.touchClient(client)
	s.Hub.EnqueueCritical(client, []byte(`{"type":"connected","version":2}`))
	connectSpan.SetAttributes(attribute.String("funkey.result", "accepted"))
	connectSpan.End()
	spanEnded = true
	go s.writePump(client)
	s.readPump(client)
	s.Hub.Remove(client)
	s.deleteClientLease(client)
}

type clientCommand struct {
	Type           string `json:"type"`
	RoomPublicID   string `json:"room_public_id,omitempty"`
	Stream         string `json:"stream,omitempty"`
	LastSequence   int64  `json:"last_sequence,omitempty"`
	ConversationID string `json:"conversation_id,omitempty"`
	Activity       string `json:"activity,omitempty"`
	CommandID      string `json:"command_id,omitempty"`
	Traceparent    string `json:"traceparent,omitempty"`
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
			s.Hub.EnqueueCritical(c, []byte(`{"type":"error","code":"invalid_message"}`))
			continue
		}
		switch command.Type {
		case "ping":
			s.Hub.Enqueue(c, []byte(`{"type":"pong"}`))
		case "subscribe":
			if !s.subscribeCommand(c, command) {
				continue
			}
		case "unsubscribe":
			s.Hub.Unsubscribe(c, command.RoomPublicID)
			s.deleteRoomLease(c, command.RoomPublicID)
		default:
			if _, allowed := allowedApplicationCommands[command.Type]; allowed {
				s.executeApplicationCommand(c, command)
				continue
			}
			s.Hub.EnqueueCritical(c, []byte(`{"type":"error","code":"unsupported_command"}`))
		}
	}
}

func (s *Server) executeApplicationCommand(c *Client, command clientCommand) {
	parent := context.Background()
	if command.Traceparent != "" {
		parent = otel.GetTextMapPropagator().Extract(
			parent,
			propagation.MapCarrier{"traceparent": command.Traceparent},
		)
	}
	parent, span := otel.Tracer("funkey.realtime").Start(
		parent,
		"realtime.command",
		trace.WithSpanKind(trace.SpanKindServer),
		trace.WithAttributes(
			attribute.String("messaging.system", "websocket"),
			attribute.String("funkey.command_type", command.Type),
		),
	)
	defer span.End()

	select {
	case s.commandSlots <- struct{}{}:
		defer func() { <-s.commandSlots }()
	case <-parent.Done():
		s.Hub.EnqueueCritical(c, []byte(`{"type":"command/error","code":"command_cancelled"}`))
		return
	default:
		s.Hub.EnqueueCritical(c, []byte(`{"type":"command/error","code":"command_busy"}`))
		return
	}

	ctx, cancel := context.WithTimeout(parent, s.Config.CommandTimeout)
	err := s.Commands.Execute(ctx, c.Token, command)
	cancel()
	if err != nil {
		if !errors.Is(err, ErrCommandRejected) {
			span.RecordError(err)
		}
		code := "command_unavailable"
		if errors.Is(err, ErrCommandRejected) {
			code = "command_rejected"
		}
		body, _ := json.Marshal(map[string]any{
			"type":         "command/error",
			"code":         code,
			"command_type": command.Type,
			"command_id":   command.CommandID,
		})
		s.Hub.EnqueueCritical(c, body)
		return
	}

	body, _ := json.Marshal(map[string]any{
		"type":         "command/ack",
		"command_type": command.Type,
		"command_id":   command.CommandID,
	})
	s.Hub.Enqueue(c, body)
}

func (s *Server) subscribeCommand(c *Client, command clientCommand) bool {
	if !validRoomID(command.RoomPublicID) {
		s.Hub.EnqueueCritical(c, []byte(`{"type":"error","code":"invalid_room"}`))
		return false
	}
	parent := context.Background()
	if command.Traceparent != "" {
		parent = otel.GetTextMapPropagator().Extract(
			parent,
			propagation.MapCarrier{"traceparent": command.Traceparent},
		)
	}
	parent, span := otel.Tracer("funkey.realtime").Start(
		parent,
		"realtime.subscribe",
		trace.WithSpanKind(trace.SpanKindServer),
		trace.WithAttributes(attribute.String("messaging.system", "websocket")),
	)
	defer span.End()
	ctx, cancel := context.WithTimeout(parent, s.Config.AuthTimeout)
	principal, err := s.verify(ctx, c.Token, "subscribe", command.RoomPublicID)
	cancel()
	if err != nil || principal.UserID != c.UserID {
		s.Hub.stats.AuthDenied.Add(1)
		s.Hub.EnqueueCritical(c, []byte(`{"type":"error","code":"subscribe_denied"}`))
		if err != nil {
			span.RecordError(err)
		}
		return false
	}
	if !s.Hub.Subscribe(c, command.RoomPublicID) {
		s.Hub.EnqueueCritical(c, []byte(`{"type":"error","code":"subscription_limit"}`))
		return false
	}
	s.touchRoomLease(c, command.RoomPublicID)

	replayed := false
	resyncRequired := false
	currentSequence := int64(0)
	if command.Stream != "" {
		replayCtx, replayCancel := context.WithTimeout(parent, 2*time.Second)
		replayed, currentSequence = s.replayRoom(
			replayCtx,
			c,
			command.RoomPublicID,
			command.Stream,
			command.LastSequence,
		)
		replayCancel()
		resyncRequired = !replayed
	}
	ack, _ := json.Marshal(map[string]any{
		"type":             "subscribed",
		"room_public_id":   command.RoomPublicID,
		"replayed":         replayed,
		"resync_required":  resyncRequired,
		"stream":           command.Stream,
		"current_sequence": currentSequence,
	})
	if !s.Hub.EnqueueCritical(c, ack) {
		return false
	}
	return true
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
		case <-c.queue.notify:
			for {
				payload, ok := c.queue.pop()
				if !ok {
					break
				}
				_ = c.Conn.SetWriteDeadline(time.Now().Add(s.Config.WriteTimeout))
				if err := c.Conn.WriteMessage(websocket.TextMessage, payload); err != nil {
					return
				}
			}
		case <-ticker.C:
			if err := c.Conn.WriteControl(websocket.PingMessage, nil, time.Now().Add(s.Config.WriteTimeout)); err != nil {
				return
			}
		case <-reauth.C:
			ctx, cancel := context.WithTimeout(context.Background(), s.Config.AuthTimeout)
			principal, err := s.verify(ctx, c.Token, "connect", "")
			cancel()
			if err != nil || principal.UserID != c.UserID || principal.IsStaff != c.IsStaff {
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
					s.deleteRoomLease(c, roomID)
					notice, _ := json.Marshal(map[string]string{"type": "subscription_revoked", "room_public_id": roomID})
					s.Hub.EnqueueCritical(c, notice)
				}
			}
		}
	}
}

func roomLeaseKey(roomID string, userID int64) string {
	return "funkey:realtime:room:leases:" + roomID + ":" + strconv.FormatInt(userID, 10)
}

func roomStreamEpochKey(roomID string) string {
	return "funkey:realtime:room:stream-epoch:" + roomID
}

func roomStreamSequenceKey(roomID string) string {
	return "funkey:realtime:room:stream-sequence:" + roomID
}

func roomReplayKey(roomID, epoch string) string {
	return "funkey:realtime:room:replay:" + roomID + ":" + epoch
}

func (s *Server) touchRoomLease(c *Client, roomID string) {
	if !validRoomID(roomID) {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	now := time.Now()
	expiresAt := float64(now.Add(s.Config.LeaseTTL).UnixMilli()) / 1000.0
	key := roomLeaseKey(roomID, c.UserID)
	pipe := s.Redis.Pipeline()
	pipe.ZAdd(ctx, key, redis.Z{Score: expiresAt, Member: c.ID})
	pipe.ZRemRangeByScore(ctx, key, "-inf", strconv.FormatFloat(float64(now.UnixMilli())/1000.0, 'f', 3, 64))
	pipe.Expire(ctx, key, s.Config.LeaseTTL*3)
	_, _ = pipe.Exec(ctx)
}

func (s *Server) deleteRoomLease(c *Client, roomID string) {
	if !validRoomID(roomID) {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = s.Redis.ZRem(ctx, roomLeaseKey(roomID, c.UserID), c.ID).Err()
}

func (s *Server) replayRoom(
	ctx context.Context,
	c *Client,
	roomID string,
	stream string,
	afterSequence int64,
) (bool, int64) {
	prefix := "room:" + roomID + ":"
	if afterSequence < 0 || !strings.HasPrefix(stream, prefix) {
		return false, 0
	}
	epoch := strings.TrimPrefix(stream, prefix)
	if epoch == "" || strings.HasPrefix(epoch, "degraded:") {
		return false, 0
	}

	values, err := s.Redis.MGet(
		ctx,
		roomStreamEpochKey(roomID),
		roomStreamSequenceKey(roomID),
	).Result()
	if err != nil || len(values) != 2 {
		return false, 0
	}
	currentEpoch := fmt.Sprint(values[0])
	currentSequence, err := strconv.ParseInt(fmt.Sprint(values[1]), 10, 64)
	if err != nil || currentEpoch != epoch {
		return false, 0
	}
	if afterSequence == currentSequence {
		return true, currentSequence
	}
	if afterSequence > currentSequence {
		return false, currentSequence
	}

	rawEvents, err := s.Redis.ZRangeByScore(
		ctx,
		roomReplayKey(roomID, epoch),
		&redis.ZRangeBy{
			Min: "(" + strconv.FormatInt(afterSequence, 10),
			Max: "+inf",
		},
	).Result()
	if err != nil || len(rawEvents) == 0 {
		return false, currentSequence
	}

	expected := afterSequence + 1
	for _, raw := range rawEvents {
		var envelope struct {
			Sequence int64 `json:"sequence"`
		}
		if err := json.Unmarshal([]byte(raw), &envelope); err != nil || envelope.Sequence != expected {
			return false, currentSequence
		}
		expected++
	}
	if expected-1 != currentSequence {
		return false, currentSequence
	}
	for _, raw := range rawEvents {
		if !s.Hub.Enqueue(c, []byte(raw)) {
			return false, currentSequence
		}
	}
	return true, currentSequence
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
	now := time.Now()
	roomLeaseScore := float64(now.Add(s.Config.LeaseTTL).UnixMilli()) / 1000.0
	roomLeaseExpiry := strconv.FormatFloat(float64(now.UnixMilli())/1000.0, 'f', 3, 64)
	for _, c := range clients {
		key := "funkey:realtime:gateway:user:" + strconv.FormatInt(c.UserID, 10) + ":" + c.ID
		pipe.Set(ctx, key, s.Config.NodeID, s.Config.LeaseTTL)
		for _, roomID := range s.Hub.Rooms(c) {
			leaseKey := roomLeaseKey(roomID, c.UserID)
			pipe.ZAdd(ctx, leaseKey, redis.Z{Score: roomLeaseScore, Member: c.ID})
			pipe.ZRemRangeByScore(ctx, leaseKey, "-inf", roomLeaseExpiry)
			pipe.Expire(ctx, leaseKey, s.Config.LeaseTTL*3)
		}
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
				if !s.Hub.EnqueueCritical(client, []byte(`{"type":"resync_required"}`)) {
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
			eventContext := context.Background()
			if event.Traceparent != "" {
				eventContext = otel.GetTextMapPropagator().Extract(
					eventContext,
					propagation.MapCarrier{"traceparent": event.Traceparent},
				)
			}
			_, span := otel.Tracer("funkey.realtime").Start(
				eventContext,
				"realtime.fanout",
				trace.WithSpanKind(trace.SpanKindConsumer),
				trace.WithAttributes(attribute.String("messaging.system", "redis")),
			)
			s.Hub.Publish(event, []byte(msg.Payload))
			span.End()
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
	if s.Auth == nil || s.Commands == nil || s.Redis == nil || s.Hub == nil {
		return fmt.Errorf("gateway dependencies are required")
	}
	return nil
}

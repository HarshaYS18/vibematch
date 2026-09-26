package gateway

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
)

type testAuthorizer struct{}

type testCommandExecutor struct {
	commands chan clientCommand
	err      error
}

func (e *testCommandExecutor) Execute(
	_ context.Context,
	_ string,
	command clientCommand,
) error {
	if e.err != nil {
		return e.err
	}
	if e.commands != nil {
		e.commands <- command
	}
	return nil
}

func (testAuthorizer) Verify(_ context.Context, token, action, roomID string) (Principal, error) {
	if token != "valid" || (action == "subscribe" && roomID != "room-a") {
		return Principal{}, ErrUnauthorized
	}
	return Principal{UserID: 7, IsStaff: true}, nil
}

func newRealtimeTestServer(t *testing.T) (*Server, *redis.Client, context.CancelFunc, string) {
	t.Helper()
	redisServer, err := miniredis.Run()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(redisServer.Close)
	redisClient := redis.NewClient(&redis.Options{Addr: redisServer.Addr()})
	t.Cleanup(func() { _ = redisClient.Close() })
	cfg := Config{
		AuthTimeout: time.Second, WriteTimeout: time.Second,
		PingInterval: time.Hour, PongTimeout: time.Hour, ReauthInterval: time.Hour,
		MaxMessageBytes: 4096, OutboundQueue: 16, MaxConnections: 10,
		MaxConnectionsPerUser: 4,
		LeaseTTL:              time.Minute, NodeID: "test-node", Origins: map[string]struct{}{},
		CommandTimeout: time.Second,
	}
	server := NewServer(
		cfg,
		testAuthorizer{},
		&testCommandExecutor{},
		redisClient,
		slog.Default(),
	)
	ctx, cancel := context.WithCancel(context.Background())
	go server.ConsumeEvents(ctx)
	deadline := time.Now().Add(time.Second)
	for !server.subscribed.Load() && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	if !server.subscribed.Load() {
		cancel()
		t.Fatal("Redis subscription did not start")
	}
	httpServer := httptest.NewServer(server.Handler())
	t.Cleanup(httpServer.Close)
	return server, redisClient, cancel, "ws" + strings.TrimPrefix(httpServer.URL, "http") + "/ws"
}

func dialRealtime(t *testing.T, wsURL string) *websocket.Conn {
	t.Helper()
	dialer := websocket.Dialer{Subprotocols: []string{"funkey.v2"}}
	header := http.Header{
		"Authorization":         []string{"Bearer valid"},
		"X-Realtime-Capability": []string{"valid"},
	}
	conn, response, err := dialer.Dial(wsURL, header)
	if err != nil {
		t.Fatalf("dial failed: %v (response %+v)", err, response)
	}
	t.Cleanup(func() { _ = conn.Close() })
	_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	var connected map[string]any
	if err := conn.ReadJSON(&connected); err != nil {
		t.Fatalf("connected ack: %v", err)
	}
	if connected["type"] != "connected" || connected["version"] != float64(2) {
		t.Fatalf("unexpected connected event: %+v", connected)
	}
	return conn
}

func TestWebSocketAuthorizesSubscriptionsAndFansOutAllScopes(t *testing.T) {
	_, redisClient, cancel, wsURL := newRealtimeTestServer(t)
	defer cancel()
	conn := dialRealtime(t, wsURL)

	if err := conn.WriteJSON(map[string]any{"type": "subscribe", "room_public_id": "room-a", "capability": "valid"}); err != nil {
		t.Fatal(err)
	}
	var ack map[string]any
	if err := conn.ReadJSON(&ack); err != nil || ack["type"] != "subscribed" {
		t.Fatalf("subscription ack: %+v, %v", ack, err)
	}

	ctx := context.Background()
	events := []Event{
		testEvent("room", 0, "room-a"),
		{EventID: "user-event", EventType: "inbox.message", EventVersion: 2, Scope: "user", UserID: 7, Payload: json.RawMessage(`{"ok":true}`)},
		{EventID: "staff-event", EventType: "moderation.task", EventVersion: 2, Scope: "staff", Payload: json.RawMessage(`{"ok":true}`)},
		{EventID: "all-event", EventType: "announcement", EventVersion: 2, Scope: "all", Payload: json.RawMessage(`{"ok":true}`)},
	}
	events[0].EventID = "room-event"
	for _, event := range events {
		raw, _ := json.Marshal(event)
		if err := redisClient.Publish(ctx, EventChannel, raw).Err(); err != nil {
			t.Fatal(err)
		}
		var received Event
		if err := conn.ReadJSON(&received); err != nil || received.EventID != event.EventID {
			t.Fatalf("event delivery: want %s, got %+v, %v", event.EventID, received, err)
		}
	}

	if err := conn.WriteJSON(map[string]string{"type": "subscribe", "room_public_id": "room-b", "capability": "valid"}); err != nil {
		t.Fatal(err)
	}
	var denial map[string]any
	if err := conn.ReadJSON(&denial); err != nil || denial["code"] != "subscribe_denied" {
		t.Fatalf("subscription denial: %+v, %v", denial, err)
	}
}

func TestRoomSubscriptionReplaysContiguousChunk20StreamAndWritesLease(t *testing.T) {
	server, redisClient, cancel, wsURL := newRealtimeTestServer(t)
	defer cancel()
	conn := dialRealtime(t, wsURL)

	ctx := context.Background()
	epoch := "epoch-a"
	stream := "room:room-a:" + epoch
	if err := redisClient.Set(ctx, roomStreamEpochKey("room-a"), epoch, time.Hour).Err(); err != nil {
		t.Fatal(err)
	}
	if err := redisClient.Set(ctx, roomStreamSequenceKey("room-a"), "2", time.Hour).Err(); err != nil {
		t.Fatal(err)
	}
	for sequence := int64(1); sequence <= 2; sequence++ {
		raw, _ := json.Marshal(map[string]any{
			"eventId":  "replay-" + string(rune('0'+sequence)),
			"type":     "room/test",
			"stream":   stream,
			"sequence": sequence,
			"payload":  map[string]any{"room_id": "room-a"},
		})
		if err := redisClient.ZAdd(ctx, roomReplayKey("room-a", epoch), redis.Z{
			Score: float64(sequence), Member: string(raw),
		}).Err(); err != nil {
			t.Fatal(err)
		}
	}

	if err := conn.WriteJSON(map[string]any{
		"type": "subscribe", "room_public_id": "room-a", "capability": "valid",
		"stream": stream, "last_sequence": 0,
	}); err != nil {
		t.Fatal(err)
	}
	for sequence := float64(1); sequence <= 2; sequence++ {
		var replay map[string]any
		if err := conn.ReadJSON(&replay); err != nil {
			t.Fatal(err)
		}
		if replay["sequence"] != sequence {
			t.Fatalf("wrong replay sequence: %+v", replay)
		}
	}
	var ack map[string]any
	if err := conn.ReadJSON(&ack); err != nil {
		t.Fatal(err)
	}
	if ack["type"] != "subscribed" || ack["replayed"] != true || ack["resync_required"] != false {
		t.Fatalf("unexpected replay ack: %+v", ack)
	}

	score, err := redisClient.ZScore(ctx, roomLeaseKey("room-a", 7), server.Hub.Clients()[0].ID).Result()
	if err != nil || score <= float64(time.Now().Unix()) {
		t.Fatalf("room lease was not created: score=%v err=%v", score, err)
	}
}

func TestWebSocketRelaysAllowlistedInboxCommand(t *testing.T) {
	redisServer, err := miniredis.Run()
	if err != nil {
		t.Fatal(err)
	}
	defer redisServer.Close()
	redisClient := redis.NewClient(&redis.Options{Addr: redisServer.Addr()})
	defer redisClient.Close()

	executor := &testCommandExecutor{commands: make(chan clientCommand, 1)}
	cfg := Config{
		AuthTimeout: time.Second, CommandTimeout: time.Second,
		WriteTimeout: time.Second, PingInterval: time.Hour,
		PongTimeout: time.Hour, ReauthInterval: time.Hour,
		MaxMessageBytes: 4096, OutboundQueue: 16, MaxConnections: 10,
		MaxConnectionsPerUser: 4, LeaseTTL: time.Minute,
		NodeID: "test-node", Origins: map[string]struct{}{},
	}
	server := NewServer(cfg, testAuthorizer{}, executor, redisClient, slog.Default())
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go server.ConsumeEvents(ctx)
	deadline := time.Now().Add(time.Second)
	for !server.subscribed.Load() && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	httpServer := httptest.NewServer(server.Handler())
	defer httpServer.Close()
	wsURL := "ws" + strings.TrimPrefix(httpServer.URL, "http") + "/ws"
	conn := dialRealtime(t, wsURL)

	if err := conn.WriteJSON(map[string]any{
		"type":            "inbox.mark_read",
		"conversation_id": "conversation-1",
		"command_id":      "cmd-1",
	}); err != nil {
		t.Fatal(err)
	}
	select {
	case command := <-executor.commands:
		if command.Type != "inbox.mark_read" ||
			command.ConversationID != "conversation-1" ||
			command.CommandID != "cmd-1" {
			t.Fatalf("unexpected relayed command: %+v", command)
		}
	case <-time.After(time.Second):
		t.Fatal("command was not relayed")
	}

	var ack map[string]any
	if err := conn.ReadJSON(&ack); err != nil {
		t.Fatal(err)
	}
	if ack["type"] != "command/ack" || ack["command_id"] != "cmd-1" {
		t.Fatalf("unexpected command ack: %+v", ack)
	}
}

func TestWebSocketRejectsUnauthorizedTokenBeforeUpgrade(t *testing.T) {
	server := NewServer(
		Config{AuthTimeout: time.Second, Origins: map[string]struct{}{}},
		testAuthorizer{},
		&testCommandExecutor{},
		nil,
		slog.Default(),
	)
	httpServer := httptest.NewServer(server.Handler())
	defer httpServer.Close()
	wsURL := "ws" + strings.TrimPrefix(httpServer.URL, "http") + "/ws"
	dialer := websocket.Dialer{}
	_, response, err := dialer.Dial(wsURL, http.Header{
		"Authorization":         []string{"Bearer invalid"},
		"X-Realtime-Capability": []string{"invalid"},
	})
	if err == nil || response == nil || response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected unauthorized upgrade, got response %+v, error %v", response, err)
	}
}

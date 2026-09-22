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

func (testAuthorizer) Verify(_ context.Context, token, action, roomID string) (Principal, error) {
	if token != "valid" || (action == "subscribe" && roomID != "room-a") {
		return Principal{}, ErrUnauthorized
	}
	return Principal{UserID: 7}, nil
}

func TestWebSocketAuthorizesSubscriptionsAndFansOutRedisEvents(t *testing.T) {
	redisServer, err := miniredis.Run()
	if err != nil {
		t.Fatal(err)
	}
	defer redisServer.Close()
	redisClient := redis.NewClient(&redis.Options{Addr: redisServer.Addr()})
	defer redisClient.Close()
	cfg := Config{
		AuthTimeout: time.Second, WriteTimeout: time.Second,
		PingInterval: time.Hour, PongTimeout: time.Hour, ReauthInterval: time.Hour,
		MaxMessageBytes: 1024, OutboundQueue: 4, MaxConnections: 10,
		LeaseTTL: time.Minute, NodeID: "test-node", Origins: map[string]struct{}{},
	}
	server := NewServer(cfg, testAuthorizer{}, redisClient, slog.Default())
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go server.ConsumeEvents(ctx)
	deadline := time.Now().Add(time.Second)
	for !server.subscribed.Load() && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	if !server.subscribed.Load() {
		t.Fatal("Redis subscription did not start")
	}
	httpServer := httptest.NewServer(server.Handler())
	defer httpServer.Close()
	wsURL := "ws" + strings.TrimPrefix(httpServer.URL, "http") + "/ws"
	dialer := websocket.Dialer{}
	header := http.Header{"Authorization": []string{"Bearer valid"}}
	conn, response, err := dialer.Dial(wsURL, header)
	if err != nil {
		t.Fatalf("dial failed: %v (response %+v)", err, response)
	}
	defer conn.Close()
	_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	if _, _, err := conn.ReadMessage(); err != nil {
		t.Fatalf("connected ack: %v", err)
	}
	if err := conn.WriteJSON(map[string]string{"type": "subscribe", "room_public_id": "room-a"}); err != nil {
		t.Fatal(err)
	}
	var ack map[string]any
	if err := conn.ReadJSON(&ack); err != nil || ack["type"] != "subscribed" {
		t.Fatalf("subscription ack: %+v, %v", ack, err)
	}
	event := testEvent("room", 0, "room-a")
	raw, _ := json.Marshal(event)
	if err := redisClient.Publish(ctx, EventChannel, raw).Err(); err != nil {
		t.Fatal(err)
	}
	var received Event
	if err := conn.ReadJSON(&received); err != nil || received.EventID != event.EventID {
		t.Fatalf("event delivery: %+v, %v", received, err)
	}
	if err := conn.WriteJSON(map[string]string{"type": "subscribe", "room_public_id": "room-b"}); err != nil {
		t.Fatal(err)
	}
	var denial map[string]any
	if err := conn.ReadJSON(&denial); err != nil || denial["code"] != "subscribe_denied" {
		t.Fatalf("subscription denial: %+v, %v", denial, err)
	}
}

func TestWebSocketRejectsUnauthorizedTokenBeforeUpgrade(t *testing.T) {
	server := NewServer(Config{AuthTimeout: time.Second, Origins: map[string]struct{}{}}, testAuthorizer{}, nil, slog.Default())
	httpServer := httptest.NewServer(server.Handler())
	defer httpServer.Close()
	wsURL := "ws" + strings.TrimPrefix(httpServer.URL, "http") + "/ws"
	dialer := websocket.Dialer{}
	_, response, err := dialer.Dial(wsURL, http.Header{"Authorization": []string{"Bearer invalid"}})
	if err == nil || response == nil || response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected unauthorized upgrade, got response %+v, error %v", response, err)
	}
}

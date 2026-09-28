package gateway

import (
	"context"
	"encoding/json"
	"log/slog"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
)

func newRevocationTestServer(t *testing.T) (*Server, *redis.Client) {
	t.Helper()
	redisServer, err := miniredis.Run()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(redisServer.Close)
	redisClient := redis.NewClient(&redis.Options{Addr: redisServer.Addr()})
	t.Cleanup(func() { _ = redisClient.Close() })
	return &Server{
		Config: Config{LeaseTTL: time.Minute},
		Hub:    NewHub(),
		Redis:  redisClient,
		Logger: slog.Default(),
	}, redisClient
}

func TestRoomPermissionRevocationDropsSubscriptionAndLease(t *testing.T) {
	server, redisClient := newRevocationTestServer(t)
	client := newClient("client-1", 7, false, "access", nil, 16)
	client.SessionID = "session-7"
	client.DeviceID = "device-7"
	if !server.Hub.Add(client, 10, 4) {
		t.Fatal("failed to add test client")
	}
	if !server.Hub.Subscribe(client, "room-a") {
		t.Fatal("failed to subscribe test client")
	}
	server.touchRoomLease(client, "room-a")

	payload, _ := json.Marshal(map[string]any{
		"room_public_id":     "room-a",
		"reason":             "room_membership_removed",
		"membership_version": 12,
	})
	server.applyCapabilityRevocation(Event{
		EventID:      "revoke-room",
		EventType:    "room.permission_revoked",
		EventVersion: 2,
		Scope:        "user",
		UserID:       7,
		Priority:     PriorityCritical,
		Payload:      payload,
	})

	if rooms := server.Hub.Rooms(client); len(rooms) != 0 {
		t.Fatalf("room subscription survived revocation: %v", rooms)
	}
	if count, err := redisClient.ZCard(
		context.Background(),
		roomLeaseKey("room-a", 7),
	).Result(); err != nil || count != 0 {
		t.Fatalf("room lease survived revocation: count=%d err=%v", count, err)
	}
	raw, ok := client.queue.pop()
	if !ok {
		t.Fatal("missing subscription_revoked notice")
	}
	var notice map[string]any
	if err := json.Unmarshal(raw, &notice); err != nil {
		t.Fatal(err)
	}
	if notice["type"] != "subscription_revoked" || notice["room_public_id"] != "room-a" {
		t.Fatalf("unexpected revocation notice: %+v", notice)
	}
}

func TestSessionRevocationClosesMatchingDeviceOnly(t *testing.T) {
	server, _ := newRevocationTestServer(t)
	oldDevice := newClient("old", 7, false, "access-old", nil, 16)
	oldDevice.SessionID = "session-old"
	oldDevice.DeviceID = "device-old"
	currentDevice := newClient("current", 7, false, "access-new", nil, 16)
	currentDevice.SessionID = "session-new"
	currentDevice.DeviceID = "device-new"
	if !server.Hub.Add(oldDevice, 10, 4) || !server.Hub.Add(currentDevice, 10, 4) {
		t.Fatal("failed to add test clients")
	}

	payload, _ := json.Marshal(map[string]any{
		"reason":    "session_replaced",
		"device_id": "device-old",
	})
	server.applyCapabilityRevocation(Event{
		EventID:      "revoke-session",
		EventType:    "auth.session_revoked",
		EventVersion: 2,
		Scope:        "user",
		UserID:       7,
		Priority:     PriorityCritical,
		Payload:      payload,
	})

	deadline := time.Now().Add(time.Second)
	for len(server.Hub.Clients()) != 1 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	clients := server.Hub.Clients()
	if len(clients) != 1 || clients[0] != currentDevice {
		t.Fatalf("unexpected clients after device revocation: %+v", clients)
	}
}

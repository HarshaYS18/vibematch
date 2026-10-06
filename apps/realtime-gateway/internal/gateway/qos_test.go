package gateway

import (
	"strings"
	"testing"
)

func TestHotRoomMetrics(t *testing.T) {
	hub := newHubWithQoS(4, 2)
	first := newClient("a", 1, false, "", nil, 8)
	second := newClient("b", 2, false, "", nil, 8)
	if !hub.Add(first, 100, 4) || !hub.Add(second, 100, 4) {
		t.Fatal("failed to add clients")
	}
	if !hub.Subscribe(first, "ROOM-QOS") || !hub.Subscribe(second, "ROOM-QOS") {
		t.Fatal("failed to subscribe clients")
	}
	metrics := hub.Metrics()
	if !strings.Contains(metrics, "funkey_realtime_hot_rooms 1") {
		t.Fatalf("expected one hot room, got %q", metrics)
	}
	if !strings.Contains(metrics, "funkey_realtime_max_room_subscribers 2") {
		t.Fatalf("expected max room subscribers=2, got %q", metrics)
	}
}

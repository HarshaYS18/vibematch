package gateway

import (
	"encoding/json"
	"testing"
	"time"
)

func testEvent(scope string, userID int64, roomID string) Event {
	return Event{
		EventID: "event-1", EventType: "room.updated", EventVersion: 1,
		Scope: scope, UserID: userID, RoomPublicID: roomID,
		Payload: json.RawMessage(`{"version":1}`),
	}
}

func TestHubRoutesOnlyAuthorizedSubscriptionsAndUsers(t *testing.T) {
	hub := NewHub()
	alice := newClient("alice", 1, "token", nil, 2)
	bob := newClient("bob", 2, "token", nil, 2)
	if !hub.Add(alice, 10, 4) || !hub.Add(bob, 10, 4) {
		t.Fatal("failed to add clients")
	}
	defer hub.CloseAll()
	if !hub.Subscribe(alice, "room-a") {
		t.Fatal("room subscription failed")
	}
	hub.Publish(testEvent("room", 0, "room-a"), []byte("room-event"))
	select {
	case got := <-alice.send:
		if string(got) != "room-event" {
			t.Fatalf("wrong event: %q", got)
		}
	default:
		t.Fatal("authorized room subscriber did not receive event")
	}
	select {
	case <-bob.send:
		t.Fatal("other user received room event")
	default:
	}
	hub.Publish(testEvent("user", 2, ""), []byte("user-event"))
	select {
	case got := <-bob.send:
		if string(got) != "user-event" {
			t.Fatalf("wrong user event: %q", got)
		}
	default:
		t.Fatal("target user did not receive event")
	}
}

func TestHubClosesSlowClientAndRejectsNewConnectionsOnDrain(t *testing.T) {
	hub := NewHub()
	client := newClient("slow", 1, "token", nil, 1)
	if !hub.Add(client, 10, 4) || !hub.Subscribe(client, "room-a") {
		t.Fatal("setup failed")
	}
	hub.Publish(testEvent("room", 0, "room-a"), []byte("first"))
	hub.Publish(testEvent("room", 0, "room-a"), []byte("second"))
	if hub.stats.SlowClosed.Load() != 1 || hub.stats.Connections.Load() != 0 {
		t.Fatal("slow client was not evicted")
	}
	hub.Drain(time.Now().Add(time.Second))
	if hub.Add(newClient("new", 2, "token", nil, 1), 10, 4) {
		t.Fatal("draining gateway accepted connection")
	}
}

func TestEventRejectsInvalidRoutingMetadata(t *testing.T) {
	invalid := []Event{
		testEvent("room", 0, ""),
		testEvent("user", 0, ""),
		testEvent("broadcast", 0, ""),
	}
	for _, event := range invalid {
		if err := event.Validate(); err == nil {
			t.Fatalf("accepted invalid event: %+v", event)
		}
	}
}


func TestHubDeduplicatesEventsAndCapsUserDevices(t *testing.T) {
	hub := NewHub()
	first := newClient("first", 7, "token", nil, 4)
	second := newClient("second", 7, "token", nil, 4)
	if !hub.Add(first, 10, 1) {
		t.Fatal("first connection rejected")
	}
	if hub.Add(second, 10, 1) {
		t.Fatal("per-user connection cap was not enforced")
	}
	if hub.stats.CapacityDenied.Load() != 1 {
		t.Fatal("capacity denial metric not incremented")
	}
	if !hub.Subscribe(first, "room-a") {
		t.Fatal("subscription failed")
	}
	event := testEvent("room", 0, "room-a")
	hub.Publish(event, []byte("first"))
	hub.Publish(event, []byte("duplicate"))
	if hub.stats.DuplicateEvents.Load() != 1 {
		t.Fatal("duplicate event was not counted")
	}
	select {
	case got := <-first.send:
		if string(got) != "first" {
			t.Fatalf("wrong payload: %q", got)
		}
	default:
		t.Fatal("first event was not delivered")
	}
	select {
	case got := <-first.send:
		t.Fatalf("duplicate event was delivered: %q", got)
	default:
	}
	hub.CloseAll()
}

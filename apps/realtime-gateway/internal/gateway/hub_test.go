package gateway

import (
	"encoding/json"
	"testing"
	"time"
)

func testEvent(scope string, userID int64, roomID string) Event {
	return Event{
		EventID: "event-1", EventType: "room.updated", EventVersion: 2,
		Scope: scope, UserID: userID, RoomPublicID: roomID,
		Payload: json.RawMessage(`{"version":1}`),
	}
}

func queuedPayload(t *testing.T, client *Client) []byte {
	t.Helper()
	payload, ok := client.queue.pop()
	if !ok {
		t.Fatal("expected queued payload")
	}
	return payload
}

func TestHubRoutesRoomUserUsersStaffAndAllScopes(t *testing.T) {
	hub := newHubWithShards(4)
	alice := newClient("alice", 1, false, "token", nil, 8)
	bob := newClient("bob", 2, true, "token", nil, 8)
	carol := newClient("carol", 3, false, "token", nil, 8)
	for _, client := range []*Client{alice, bob, carol} {
		if !hub.Add(client, 10, 4) {
			t.Fatal("failed to add client")
		}
	}
	defer hub.CloseAll()
	if !hub.Subscribe(alice, "room-a") || !hub.Subscribe(bob, "room-a") {
		t.Fatal("room subscription failed")
	}

	roomEvent := testEvent("room", 0, "room-a")
	hub.Publish(roomEvent, []byte("room-event"))
	if got := string(queuedPayload(t, alice)); got != "room-event" {
		t.Fatalf("wrong room event for alice: %q", got)
	}
	if got := string(queuedPayload(t, bob)); got != "room-event" {
		t.Fatalf("wrong room event for bob: %q", got)
	}
	if _, ok := carol.queue.pop(); ok {
		t.Fatal("non-subscriber received room event")
	}

	userEvent := testEvent("user", 3, "")
	userEvent.EventID = "event-2"
	hub.Publish(userEvent, []byte("user-event"))
	if got := string(queuedPayload(t, carol)); got != "user-event" {
		t.Fatalf("wrong user event: %q", got)
	}

	usersEvent := testEvent("users", 0, "")
	usersEvent.EventID = "event-3"
	usersEvent.UserIDs = []int64{1, 3}
	hub.Publish(usersEvent, []byte("users-event"))
	if got := string(queuedPayload(t, alice)); got != "users-event" {
		t.Fatalf("wrong users event for alice: %q", got)
	}
	if got := string(queuedPayload(t, carol)); got != "users-event" {
		t.Fatalf("wrong users event for carol: %q", got)
	}
	if _, ok := bob.queue.pop(); ok {
		t.Fatal("unlisted user received users-scope event")
	}

	staffEvent := testEvent("staff", 0, "")
	staffEvent.EventID = "event-4"
	hub.Publish(staffEvent, []byte("staff-event"))
	if got := string(queuedPayload(t, bob)); got != "staff-event" {
		t.Fatalf("wrong staff event: %q", got)
	}
	if _, ok := alice.queue.pop(); ok {
		t.Fatal("non-staff user received staff event")
	}

	allEvent := testEvent("all", 0, "")
	allEvent.EventID = "event-5"
	hub.Publish(allEvent, []byte("all-event"))
	for _, client := range []*Client{alice, bob, carol} {
		if got := string(queuedPayload(t, client)); got != "all-event" {
			t.Fatalf("wrong all event for %s: %q", client.ID, got)
		}
	}
}

func TestHubPriorityQueueDropsBestEffortAndProtectsCritical(t *testing.T) {
	hub := NewHub()
	client := newClient("slow", 1, false, "token", nil, 4)
	if !hub.Add(client, 10, 4) || !hub.Subscribe(client, "room-a") {
		t.Fatal("setup failed")
	}

	for index := 0; index < 4; index++ {
		event := testEvent("room", 0, "room-a")
		event.EventID = "normal-" + string(rune('a'+index))
		hub.Publish(event, []byte("normal"))
	}
	bestEffort := testEvent("room", 0, "room-a")
	bestEffort.EventID = "best"
	bestEffort.EventType = "inbox.typing"
	bestEffort.Priority = PriorityBestEffort
	hub.Publish(bestEffort, []byte("best"))
	if hub.stats.BestEffortDropped.Load() != 1 {
		t.Fatal("best-effort overflow was not dropped")
	}
	if hub.stats.Connections.Load() != 1 {
		t.Fatal("best-effort overflow closed the client")
	}

	critical := testEvent("room", 0, "room-a")
	critical.EventID = "critical"
	critical.EventType = "session_replaced"
	critical.Priority = PriorityCritical
	hub.Publish(critical, []byte("critical"))
	if hub.stats.LowerPriorityEvict.Load() != 1 {
		t.Fatal("critical traffic did not evict lower priority work")
	}
	if got := string(queuedPayload(t, client)); got != "critical" {
		t.Fatalf("critical message was not first: %q", got)
	}
	hub.CloseAll()
}

func TestHubClosesSlowClientWhenRequiredTrafficCannotFit(t *testing.T) {
	hub := NewHub()
	client := newClient("slow", 1, false, "token", nil, 4)
	if !hub.Add(client, 10, 4) || !hub.Subscribe(client, "room-a") {
		t.Fatal("setup failed")
	}
	for index := 0; index < 4; index++ {
		event := testEvent("room", 0, "room-a")
		event.EventID = "critical-" + string(rune('a'+index))
		event.Priority = PriorityCritical
		hub.Publish(event, []byte("critical"))
	}
	overflow := testEvent("room", 0, "room-a")
	overflow.EventID = "critical-overflow"
	overflow.Priority = PriorityCritical
	hub.Publish(overflow, []byte("overflow"))
	if hub.stats.SlowClosed.Load() != 1 || hub.stats.Connections.Load() != 0 {
		t.Fatal("required traffic overflow did not evict slow client")
	}
	hub.Drain(time.Now().Add(time.Second))
	if hub.Add(newClient("new", 2, false, "token", nil, 4), 10, 4) {
		t.Fatal("draining gateway accepted connection")
	}
}

func TestEventRejectsInvalidRoutingMetadata(t *testing.T) {
	invalid := []Event{
		testEvent("room", 0, ""),
		testEvent("user", 0, ""),
		testEvent("users", 0, ""),
		testEvent("broadcast", 0, ""),
	}
	for _, event := range invalid {
		if err := event.Validate(); err == nil {
			t.Fatalf("accepted invalid event: %+v", event)
		}
	}
}

func TestHubDeduplicatesEventsCapsUserDevicesAndBoundsDedupe(t *testing.T) {
	hub := newHubWithShards(2)
	hub.dedupe = newBoundedDedupe(2, time.Hour)
	first := newClient("first", 7, false, "token", nil, 8)
	second := newClient("second", 7, false, "token", nil, 8)
	if !hub.Add(first, 10, 1) {
		t.Fatal("first connection rejected")
	}
	if hub.Add(second, 10, 1) {
		t.Fatal("per-user connection cap was not enforced")
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
	if got := string(queuedPayload(t, first)); got != "first" {
		t.Fatalf("wrong payload: %q", got)
	}

	for _, id := range []string{"event-2", "event-3"} {
		next := testEvent("room", 0, "room-a")
		next.EventID = id
		hub.Publish(next, []byte(id))
		_ = queuedPayload(t, first)
	}
	if hub.dedupe.size() > 2 {
		t.Fatalf("dedupe cache exceeded bound: %d", hub.dedupe.size())
	}
	hub.CloseAll()
}

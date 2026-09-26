package gateway

import (
	"encoding/json"
	"errors"
	"strings"
)

const EventChannel = "funkey:realtime:events"

const (
	PriorityCritical   = "critical"
	PriorityNormal     = "normal"
	PriorityBestEffort = "best_effort"
)

// Event is published by authoritative backend/domain services only. The
// gateway validates routing metadata and transport hints but never interprets
// the payload as durable truth.
type Event struct {
	EventID       string          `json:"event_id"`
	EventType     string          `json:"event_type"`
	EventVersion  int             `json:"event_version"`
	Type          string          `json:"type,omitempty"`
	Stream        string          `json:"stream,omitempty"`
	Sequence      int64           `json:"sequence,omitempty"`
	ServerTime    string          `json:"serverTime,omitempty"`
	TraceID       string          `json:"trace_id,omitempty"`
	Traceparent   string          `json:"traceparent,omitempty"`
	Scope         string          `json:"scope"`
	RoomPublicID  string          `json:"room_public_id,omitempty"`
	UserID        int64           `json:"user_id,omitempty"`
	UserIDs       []int64         `json:"user_ids,omitempty"`
	Priority      string          `json:"priority,omitempty"`
	RoomVersion   int64           `json:"room_version,omitempty"`
	EventSequence int64           `json:"event_sequence,omitempty"`
	Payload       json.RawMessage `json:"payload"`
}

func (e Event) Validate() error {
	if e.EventID == "" || e.EventType == "" || e.EventVersion < 1 || len(e.Payload) == 0 || !json.Valid(e.Payload) {
		return errors.New("invalid event envelope")
	}
	switch e.Priority {
	case "", PriorityCritical, PriorityNormal, PriorityBestEffort:
	default:
		return errors.New("invalid event priority")
	}
	switch e.Scope {
	case "room":
		if e.RoomPublicID == "" || len(e.RoomPublicID) > 128 || strings.ContainsAny(e.RoomPublicID, " \r\n\t") {
			return errors.New("invalid room scope")
		}
	case "user":
		if e.UserID <= 0 {
			return errors.New("invalid user scope")
		}
	case "users":
		if len(e.UserIDs) == 0 || len(e.UserIDs) > 256 {
			return errors.New("invalid users scope")
		}
		for _, userID := range e.UserIDs {
			if userID <= 0 {
				return errors.New("invalid users scope")
			}
		}
	case "staff", "all":
	default:
		return errors.New("unknown event scope")
	}
	return nil
}

func (e Event) DeliveryPriority() string {
	if e.Priority != "" {
		return e.Priority
	}
	eventType := strings.ToLower(e.EventType)
	switch {
	case strings.Contains(eventType, "session_replaced"),
		strings.Contains(eventType, "subscription_revoked"),
		strings.Contains(eventType, "moderation"),
		strings.Contains(eventType, "ban"),
		strings.Contains(eventType, "resync"):
		return PriorityCritical
	case strings.Contains(eventType, "typing"),
		strings.Contains(eventType, "chat_activity"),
		strings.Contains(eventType, "presence"):
		return PriorityBestEffort
	default:
		return PriorityNormal
	}
}

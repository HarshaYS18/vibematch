package gateway

import (
	"encoding/json"
	"errors"
	"strings"
)

const EventChannel = "funkey:realtime:events"

// Event is published by the authoritative backend only. The gateway validates
// routing metadata but never interprets payloads as commands or durable truth.
type Event struct {
	EventID      string          `json:"event_id"`
	EventType    string          `json:"event_type"`
	EventVersion int             `json:"event_version"`
	Scope        string          `json:"scope"`
	RoomPublicID string          `json:"room_public_id,omitempty"`
	UserID       int64           `json:"user_id,omitempty"`
	Payload      json.RawMessage `json:"payload"`
}

func (e Event) Validate() error {
	if e.EventID == "" || e.EventType == "" || e.EventVersion < 1 || len(e.Payload) == 0 || !json.Valid(e.Payload) {
		return errors.New("invalid event envelope")
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
	default:
		return errors.New("unknown event scope")
	}
	return nil
}

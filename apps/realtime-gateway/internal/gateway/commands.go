package gateway

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

var ErrCommandRejected = errors.New("realtime command rejected")

var allowedApplicationCommands = map[string]struct{}{
	"inbox.chat_activity": {},
	"inbox.typing_start":  {},
	"inbox.typing_stop":   {},
	"inbox.mark_read":     {},

	"room/join":                            {},
	"room/leave":                           {},
	"seat/take":                            {},
	"seat/leave":                           {},
	"seat_invite/send":                     {},
	"seat_invite/accept":                   {},
	"seat_invite/reject":                   {},
	"seat_application/request":             {},
	"seat_application/reject":              {},
	"admin/seat_assign":                    {},
	"admin/seat_leave":                     {},
	"admin/seat_leave_lock":                {},
	"admin/seat_lock":                      {},
	"admin/seat_unlock":                    {},
	"mic/set_enabled":                      {},
	"admin_mute/set":                       {},
	"admin/kick":                           {},
	"admin/kick_remove":                    {},
	"room_member/request":                  {},
	"room_member/approve":                  {},
	"room_member/reject":                   {},
	"room_member/remove":                   {},
	"room_admin/set":                       {},
	"room_music/control_external":          {},
	"room_music/stop_external":             {},
	"room_music/producer_started_external": {},
	"room_settings/seat_layout":            {},
	"room_settings/background_theme":       {},
	"room_settings/privacy":                {},
	"room_settings/screenshots":            {},
	"room_settings/images":                 {},
	"room_settings/guest_messages":         {},
	"room_settings/apply_mode":             {},
	"room_settings/announcement":           {},
	"room_chat/send":                       {},
	"room/chat":                            {},
	"room/chat_clear":                      {},
	"room/system_message":                  {},
	"profile/update":                       {},
	"room_cricket/start":                   {},
	"room_cricket/end":                     {},
	"room_activity/start":                  {},
	"room_activity/update":                 {},
	"room_activity/end":                    {},
	"watch_party/load":                     {},
	"watch_party/play":                     {},
	"watch_party/pause":                    {},
	"watch_party/seek":                     {},
	"watch_party/change_content":           {},
	"watch_party/sync":                     {},
	"watch_party/end":                      {},
	"watch_party/transfer_control":         {},
}

type CommandExecutor interface {
	Execute(ctx context.Context, token string, command clientCommand) error
}

type HTTPCommandExecutor struct {
	URL    string
	Client *http.Client
}

func NewHTTPCommandExecutor(url string, timeout time.Duration) *HTTPCommandExecutor {
	return &HTTPCommandExecutor{
		URL: strings.TrimSpace(url),
		Client: &http.Client{
			Timeout: timeout,
			Transport: otelhttp.NewTransport(&http.Transport{
				MaxIdleConns:        100,
				MaxIdleConnsPerHost: 100,
				IdleConnTimeout:     90 * time.Second,
			}),
		},
	}
}

func (e *HTTPCommandExecutor) Execute(
	ctx context.Context,
	token string,
	command clientCommand,
) error {
	if e == nil || e.URL == "" || token == "" {
		return ErrCommandRejected
	}
	if _, allowed := allowedApplicationCommands[command.Type]; !allowed {
		return ErrCommandRejected
	}
	isInbox := strings.HasPrefix(command.Type, "inbox.")
	if isInbox && strings.TrimSpace(command.ConversationID) == "" {
		return ErrCommandRejected
	}
	if !isInbox && strings.TrimSpace(command.RoomPublicID) == "" {
		return ErrCommandRejected
	}

	body, err := json.Marshal(map[string]any{
		"type":            command.Type,
		"room_public_id":  command.RoomPublicID,
		"conversation_id": command.ConversationID,
		"activity":        command.Activity,
		"command_id":      command.CommandID,
		"payload":         command.Payload,
	})
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		e.URL,
		bytes.NewReader(body),
	)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	if command.Traceparent != "" {
		req.Header.Set("traceparent", command.Traceparent)
	}

	resp, err := e.Client.Do(req)
	if err != nil {
		return fmt.Errorf("command service unavailable: %w", err)
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))

	if resp.StatusCode >= 400 && resp.StatusCode < 500 {
		return ErrCommandRejected
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("command service status %d", resp.StatusCode)
	}
	return nil
}

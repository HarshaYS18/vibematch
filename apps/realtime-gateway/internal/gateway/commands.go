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
	"inbox.typing_start":   {},
	"inbox.typing_stop":    {},
	"inbox.mark_read":      {},
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
	if strings.TrimSpace(command.ConversationID) == "" {
		return ErrCommandRejected
	}

	body, err := json.Marshal(map[string]any{
		"type":            command.Type,
		"conversation_id": command.ConversationID,
		"activity":        command.Activity,
		"command_id":      command.CommandID,
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

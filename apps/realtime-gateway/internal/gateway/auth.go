package gateway

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

type Principal struct {
	UserID            int64
	IsStaff           bool
	SessionID         string
	DeviceID          string
	Permissions       []string
	MembershipVersion int64
}

type Authorizer interface {
	Verify(ctx context.Context, token, action, roomID string) (Principal, error)
}

type HTTPAuthorizer struct {
	URL    string
	Client *http.Client
}

type verifyRequest struct {
	RequestedAction string `json:"requested_action"`
	RoomPublicID    string `json:"room_public_id,omitempty"`
}

type verifyResponse struct {
	Allowed bool  `json:"allowed"`
	UserID  int64 `json:"user_id"`
	IsStaff bool  `json:"is_staff"`
}

var ErrUnauthorized = errors.New("authorization denied")

func NewHTTPAuthorizer(url string, timeout time.Duration) *HTTPAuthorizer {
	return &HTTPAuthorizer{
		URL: url,
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

func (a *HTTPAuthorizer) Verify(ctx context.Context, token, action, roomID string) (Principal, error) {
	if token == "" || (action != "connect" && action != "subscribe") {
		return Principal{}, ErrUnauthorized
	}
	body, _ := json.Marshal(verifyRequest{RequestedAction: action, RoomPublicID: roomID})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.URL, bytes.NewReader(body))
	if err != nil {
		return Principal{}, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := a.Client.Do(req)
	if err != nil {
		return Principal{}, fmt.Errorf("auth service unavailable: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 && resp.StatusCode < 500 {
		return Principal{}, ErrUnauthorized
	}
	if resp.StatusCode != http.StatusOK {
		return Principal{}, fmt.Errorf("auth service status %d", resp.StatusCode)
	}
	var result verifyResponse
	if err := json.NewDecoder(io.LimitReader(resp.Body, 4096)).Decode(&result); err != nil {
		return Principal{}, fmt.Errorf("invalid auth response: %w", err)
	}
	if !result.Allowed || result.UserID <= 0 {
		return Principal{}, ErrUnauthorized
	}
	return Principal{UserID: result.UserID, IsStaff: result.IsStaff}, nil
}

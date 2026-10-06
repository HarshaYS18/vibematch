package gateway

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

const capabilityMaxLifetime = 15 * time.Minute

type capabilityHeader struct {
	Algorithm string `json:"alg"`
	Type      string `json:"typ"`
	KeyID     string `json:"kid"`
}

type capabilityClaims struct {
	Issuer            string   `json:"iss"`
	Audience          string   `json:"aud"`
	Type              string   `json:"type"`
	UserID            int64    `json:"user_id"`
	SessionID         string   `json:"session_id"`
	DeviceID          string   `json:"device_id"`
	Scopes            []string `json:"scopes"`
	IssuedAt          int64    `json:"iat"`
	NotBefore         int64    `json:"nbf"`
	ExpiresAt         int64    `json:"exp"`
	TokenVersion      int      `json:"token_version"`
	IsStaff           bool     `json:"is_staff"`
	RoomID            string   `json:"room_id,omitempty"`
	Permissions       []string `json:"permissions,omitempty"`
	MembershipVersion int64    `json:"membership_version,omitempty"`
}

type capabilityJWK struct {
	KeyType      string `json:"kty"`
	Curve        string `json:"crv"`
	Algorithm    string `json:"alg"`
	KeyID        string `json:"kid"`
	X            string `json:"x"`
	Issuer       string `json:"issuer"`
	Audience     string `json:"audience"`
	TokenVersion int    `json:"token_version"`
}

type CapabilityAuthorizer struct {
	URL          string
	Issuer       string
	Audience     string
	TokenVersion int
	Client       *http.Client

	keyMu sync.RWMutex
	keyID string
	key   ed25519.PublicKey

	refreshMu sync.Mutex
}

func NewCapabilityAuthorizer(
	url, issuer, audience string,
	tokenVersion int,
	timeout time.Duration,
) *CapabilityAuthorizer {
	return &CapabilityAuthorizer{
		URL:          url,
		Issuer:       issuer,
		Audience:     audience,
		TokenVersion: tokenVersion,
		Client: &http.Client{
			Timeout: timeout,
			Transport: otelhttp.NewTransport(&http.Transport{
				MaxIdleConns:        16,
				MaxIdleConnsPerHost: 8,
				IdleConnTimeout:     90 * time.Second,
			}),
		},
	}
}

func (a *CapabilityAuthorizer) Verify(
	ctx context.Context,
	token, action, roomID string,
) (Principal, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 || (action != "connect" && action != "subscribe") {
		return Principal{}, ErrUnauthorized
	}

	headerRaw, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return Principal{}, ErrUnauthorized
	}
	payloadRaw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return Principal{}, ErrUnauthorized
	}
	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || len(signature) != ed25519.SignatureSize {
		return Principal{}, ErrUnauthorized
	}

	var header capabilityHeader
	var claims capabilityClaims
	if json.Unmarshal(headerRaw, &header) != nil || json.Unmarshal(payloadRaw, &claims) != nil {
		return Principal{}, ErrUnauthorized
	}
	if header.Algorithm != "EdDSA" || header.Type != "JWT" || header.KeyID == "" {
		return Principal{}, ErrUnauthorized
	}

	key, err := a.publicKey(ctx, header.KeyID)
	if err != nil {
		return Principal{}, err
	}
	if !ed25519.Verify(key, []byte(parts[0]+"."+parts[1]), signature) {
		return Principal{}, ErrUnauthorized
	}

	now := time.Now().Unix()
	if claims.Issuer != a.Issuer ||
		claims.Audience != a.Audience ||
		claims.Type != "realtime_capability" ||
		claims.TokenVersion != a.TokenVersion ||
		claims.UserID <= 0 ||
		strings.TrimSpace(claims.SessionID) == "" ||
		claims.IssuedAt <= 0 ||
		claims.ExpiresAt <= claims.IssuedAt ||
		claims.ExpiresAt < now-30 ||
		claims.IssuedAt > now+30 ||
		claims.NotBefore > now+30 ||
		time.Duration(claims.ExpiresAt-claims.IssuedAt)*time.Second > capabilityMaxLifetime {
		return Principal{}, ErrUnauthorized
	}

	requiredScope := "realtime:connect"
	if action == "subscribe" {
		requiredScope = "room:subscribe"
		if !validRoomID(roomID) || claims.RoomID != roomID {
			return Principal{}, ErrUnauthorized
		}
	}
	if !containsString(claims.Scopes, requiredScope) {
		return Principal{}, ErrUnauthorized
	}

	return Principal{
		UserID:            claims.UserID,
		IsStaff:           claims.IsStaff,
		SessionID:         claims.SessionID,
		DeviceID:          claims.DeviceID,
		Permissions:       append([]string(nil), claims.Permissions...),
		MembershipVersion: claims.MembershipVersion,
	}, nil
}

func (a *CapabilityAuthorizer) publicKey(ctx context.Context, keyID string) (ed25519.PublicKey, error) {
	a.keyMu.RLock()
	if a.keyID == keyID && len(a.key) == ed25519.PublicKeySize {
		key := append(ed25519.PublicKey(nil), a.key...)
		a.keyMu.RUnlock()
		return key, nil
	}
	a.keyMu.RUnlock()

	a.refreshMu.Lock()
	defer a.refreshMu.Unlock()

	a.keyMu.RLock()
	if a.keyID == keyID && len(a.key) == ed25519.PublicKeySize {
		key := append(ed25519.PublicKey(nil), a.key...)
		a.keyMu.RUnlock()
		return key, nil
	}
	a.keyMu.RUnlock()

	if err := a.refresh(ctx); err != nil {
		return nil, err
	}
	a.keyMu.RLock()
	defer a.keyMu.RUnlock()
	if a.keyID != keyID || len(a.key) != ed25519.PublicKeySize {
		return nil, ErrUnauthorized
	}
	return append(ed25519.PublicKey(nil), a.key...), nil
}

func (a *CapabilityAuthorizer) refresh(ctx context.Context) error {
	if strings.TrimSpace(a.URL) == "" {
		return errors.New("realtime capability key URL is required")
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.URL, nil)
	if err != nil {
		return err
	}
	resp, err := a.Client.Do(req)
	if err != nil {
		return fmt.Errorf("capability key service unavailable: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("capability key service status %d", resp.StatusCode)
	}
	var jwk capabilityJWK
	if err := json.NewDecoder(io.LimitReader(resp.Body, 8192)).Decode(&jwk); err != nil {
		return fmt.Errorf("invalid capability key response: %w", err)
	}
	if jwk.KeyType != "OKP" ||
		jwk.Curve != "Ed25519" ||
		jwk.Algorithm != "EdDSA" ||
		jwk.KeyID == "" ||
		jwk.Issuer != a.Issuer ||
		jwk.Audience != a.Audience ||
		jwk.TokenVersion != a.TokenVersion {
		return errors.New("capability key metadata mismatch")
	}
	raw, err := base64.RawURLEncoding.DecodeString(jwk.X)
	if err != nil || len(raw) != ed25519.PublicKeySize {
		return errors.New("invalid Ed25519 capability public key")
	}
	a.keyMu.Lock()
	a.keyID = jwk.KeyID
	a.key = append(ed25519.PublicKey(nil), raw...)
	a.keyMu.Unlock()
	return nil
}

func containsString(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}

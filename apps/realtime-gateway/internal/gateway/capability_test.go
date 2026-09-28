package gateway

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func signCapability(
	t *testing.T,
	privateKey ed25519.PrivateKey,
	keyID string,
	claims map[string]any,
) string {
	t.Helper()
	header, _ := json.Marshal(map[string]any{"alg": "EdDSA", "typ": "JWT", "kid": keyID})
	payload, _ := json.Marshal(claims)
	head := base64.RawURLEncoding.EncodeToString(header)
	body := base64.RawURLEncoding.EncodeToString(payload)
	signature := ed25519.Sign(privateKey, []byte(head+"."+body))
	return head + "." + body + "." + base64.RawURLEncoding.EncodeToString(signature)
}

func newCapabilityTestAuthorizer(t *testing.T) (*CapabilityAuthorizer, ed25519.PrivateKey, string) {
	t.Helper()
	publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	keyID := "test-key"
	keyServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"kty": "OKP", "crv": "Ed25519", "alg": "EdDSA", "kid": keyID,
			"x":      base64.RawURLEncoding.EncodeToString(publicKey),
			"issuer": "funkey-api", "audience": "funkey-realtime", "token_version": 1,
		})
	}))
	t.Cleanup(keyServer.Close)
	return NewCapabilityAuthorizer(
		keyServer.URL,
		"funkey-api",
		"funkey-realtime",
		1,
		time.Second,
	), privateKey, keyID
}

func TestCapabilityAuthorizerVerifiesConnectAndRoomLocally(t *testing.T) {
	authorizer, privateKey, keyID := newCapabilityTestAuthorizer(t)
	now := time.Now().Unix()
	base := map[string]any{
		"iss": "funkey-api", "aud": "funkey-realtime", "type": "realtime_capability",
		"user_id": 7, "session_id": "session-7", "device_id": "device-7",
		"iat": now, "nbf": now - 1, "exp": now + 300, "token_version": 1,
		"is_staff": true,
	}

	connectClaims := cloneCapabilityClaims(base)
	connectClaims["scopes"] = []string{"realtime:connect"}
	connect := signCapability(t, privateKey, keyID, connectClaims)
	principal, err := authorizer.Verify(context.Background(), connect, "connect", "")
	if err != nil || principal.UserID != 7 || !principal.IsStaff || principal.SessionID != "session-7" {
		t.Fatalf("connect capability rejected: %+v %v", principal, err)
	}

	roomClaims := cloneCapabilityClaims(base)
	roomClaims["scopes"] = []string{"room:subscribe"}
	roomClaims["room_id"] = "room-a"
	roomClaims["permissions"] = []string{"CAN_LISTEN"}
	roomClaims["membership_version"] = 11
	room := signCapability(t, privateKey, keyID, roomClaims)
	principal, err = authorizer.Verify(context.Background(), room, "subscribe", "room-a")
	if err != nil || principal.MembershipVersion != 11 || !containsString(principal.Permissions, "CAN_LISTEN") {
		t.Fatalf("room capability rejected: %+v %v", principal, err)
	}
}

func TestCapabilityAuthorizerRejectsWrongRoomExpiredAndTamperedTokens(t *testing.T) {
	authorizer, privateKey, keyID := newCapabilityTestAuthorizer(t)
	now := time.Now().Unix()
	claims := map[string]any{
		"iss": "funkey-api", "aud": "funkey-realtime", "type": "realtime_capability",
		"user_id": 7, "session_id": "s", "device_id": "d",
		"scopes": []string{"room:subscribe"}, "room_id": "room-a",
		"iat": now, "nbf": now - 1, "exp": now + 60, "token_version": 1,
	}
	token := signCapability(t, privateKey, keyID, claims)
	if _, err := authorizer.Verify(context.Background(), token, "subscribe", "room-b"); err != ErrUnauthorized {
		t.Fatalf("wrong-room capability accepted: %v", err)
	}

	expired := cloneCapabilityClaims(claims)
	expired["iat"] = now - 120
	expired["exp"] = now - 60
	if _, err := authorizer.Verify(
		context.Background(),
		signCapability(t, privateKey, keyID, expired),
		"subscribe",
		"room-a",
	); err != ErrUnauthorized {
		t.Fatalf("expired capability accepted: %v", err)
	}

	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("unexpected signed capability shape: %q", token)
	}
	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || len(signature) != ed25519.SignatureSize {
		t.Fatalf("invalid test signature: len=%d err=%v", len(signature), err)
	}
	signature[0] ^= 0x01
	tampered := parts[0] + "." + parts[1] + "." +
		base64.RawURLEncoding.EncodeToString(signature)
	if _, err := authorizer.Verify(context.Background(), tampered, "subscribe", "room-a"); err == nil {
		t.Fatal("tampered capability accepted")
	}
}

func cloneCapabilityClaims(source map[string]any) map[string]any {
	out := make(map[string]any, len(source))
	for key, value := range source {
		out[key] = value
	}
	return out
}

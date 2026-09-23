package gateway

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestHTTPAuthorizerDelegatesToControlPlane(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.Header.Get("Authorization") != "Bearer valid-token" {
			t.Error("missing bearer authorization")
		}
		if r.URL.Path != "/api/v1/realtime/verify" {
			t.Error("wrong authorization endpoint")
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"allowed":true,"user_id":123,"is_staff":true}`))
	}))
	defer server.Close()
	auth := NewHTTPAuthorizer(server.URL+"/api/v1/realtime/verify", time.Second)
	principal, err := auth.Verify(context.Background(), "valid-token", "subscribe", "ROOM1")
	if err != nil || principal.UserID != 123 || !principal.IsStaff {
		t.Fatalf("unexpected result: %+v, %v", principal, err)
	}
}

func TestHTTPAuthorizerRejectsControlPlaneDenial(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "denied", http.StatusForbidden)
	}))
	defer server.Close()
	auth := NewHTTPAuthorizer(server.URL, time.Second)
	_, err := auth.Verify(context.Background(), "token", "connect", "")
	if !errors.Is(err, ErrUnauthorized) {
		t.Fatalf("expected authorization denial, got %v", err)
	}
}

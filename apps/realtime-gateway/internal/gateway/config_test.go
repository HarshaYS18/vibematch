package gateway

import "testing"

func TestProductionConfigRequiresOriginAndRedis(t *testing.T) {
	t.Setenv("APP_ENV", "production")
	t.Setenv("REALTIME_AUTH_VERIFY_URL", "http://api:8000/api/v1/realtime/verify")
	t.Setenv("REALTIME_ORIGINS", "")
	t.Setenv("REALTIME_REDIS_URL", "")
	if _, err := LoadConfig(); err == nil {
		t.Fatal("production config accepted empty origin allowlist")
	}
	t.Setenv("REALTIME_ORIGINS", "https://funkey.example")
	if _, err := LoadConfig(); err == nil {
		t.Fatal("production config accepted implicit local Redis")
	}
	t.Setenv("REALTIME_REDIS_URL", "redis://redis:6379/0")
	if _, err := LoadConfig(); err != nil {
		t.Fatalf("production config unexpectedly rejected: %v", err)
	}
}

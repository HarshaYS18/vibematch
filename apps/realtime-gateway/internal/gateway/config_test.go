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

func TestRedisPoolAndLeaseConfiguration(t *testing.T) {
	t.Setenv("REALTIME_AUTH_VERIFY_URL", "http://api:8000/api/v1/realtime/verify")
	t.Setenv("REALTIME_REDIS_POOL_SIZE", "77")
	t.Setenv("REALTIME_REDIS_POOL_TIMEOUT", "1500ms")
	t.Setenv("REALTIME_REDIS_READ_TIMEOUT", "900ms")
	t.Setenv("REALTIME_REDIS_WRITE_TIMEOUT", "1100ms")
	t.Setenv("REALTIME_REDIS_LEASE_TTL", "45s")
	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig() error = %v", err)
	}
	if cfg.RedisPoolSize != 77 || cfg.RedisPoolTimeout.String() != "1.5s" {
		t.Fatalf("unexpected Redis pool config: %+v", cfg)
	}
	if cfg.RedisReadTimeout.String() != "900ms" || cfg.RedisWriteTimeout.String() != "1.1s" {
		t.Fatalf("unexpected Redis IO timeouts: %+v", cfg)
	}
	if cfg.LeaseTTL.String() != "45s" {
		t.Fatalf("unexpected Redis lease TTL: %v", cfg.LeaseTTL)
	}

	t.Setenv("REALTIME_REDIS_POOL_SIZE", "0")
	if _, err := LoadConfig(); err == nil {
		t.Fatal("LoadConfig accepted zero Redis pool size")
	}
}

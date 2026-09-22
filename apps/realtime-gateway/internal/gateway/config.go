package gateway

import (
	"errors"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	ListenAddr            string
	AuthVerifyURL         string
	RedisURL              string
	NodeID                string
	Origins               map[string]struct{}
	DrainTimeout          time.Duration
	AuthTimeout           time.Duration
	WriteTimeout          time.Duration
	PingInterval          time.Duration
	PongTimeout           time.Duration
	ReauthInterval        time.Duration
	LeaseTTL              time.Duration
	MaxMessageBytes       int64
	OutboundQueue         int
	MaxConnections        int64
	MaxConnectionsPerUser int
}

func env(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func LoadConfig() (Config, error) {
	cfg := Config{
		ListenAddr:            env("REALTIME_LISTEN_ADDR", ":8081"),
		AuthVerifyURL:         strings.TrimSpace(os.Getenv("REALTIME_AUTH_VERIFY_URL")),
		RedisURL:              env("REALTIME_REDIS_URL", "redis://127.0.0.1:6379/0"),
		NodeID:                env("REALTIME_NODE_ID", env("HOSTNAME", "gateway-local")),
		Origins:               make(map[string]struct{}),
		DrainTimeout:          45 * time.Second,
		AuthTimeout:           3 * time.Second,
		WriteTimeout:          5 * time.Second,
		PingInterval:          20 * time.Second,
		PongTimeout:           60 * time.Second,
		ReauthInterval:        5 * time.Minute,
		LeaseTTL:              60 * time.Second,
		MaxMessageBytes:       16 * 1024,
		OutboundQueue:         64,
		MaxConnections:        10000,
		MaxConnectionsPerUser: 4,
	}
	if cfg.AuthVerifyURL == "" {
		return cfg, errors.New("REALTIME_AUTH_VERIFY_URL is required")
	}
	if raw := os.Getenv("REALTIME_DRAIN_TIMEOUT"); raw != "" {
		value, err := time.ParseDuration(raw)
		if err != nil || value <= 0 {
			return cfg, errors.New("REALTIME_DRAIN_TIMEOUT must be a positive duration")
		}
		cfg.DrainTimeout = value
	}
	if raw := os.Getenv("REALTIME_MAX_CONNECTIONS"); raw != "" {
		value, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || value <= 0 {
			return cfg, errors.New("REALTIME_MAX_CONNECTIONS must be positive")
		}
		cfg.MaxConnections = value
	}
	if raw := os.Getenv("REALTIME_MAX_CONNECTIONS_PER_USER"); raw != "" {
		value, err := strconv.Atoi(raw)
		if err != nil || value <= 0 {
			return cfg, errors.New("REALTIME_MAX_CONNECTIONS_PER_USER must be positive")
		}
		cfg.MaxConnectionsPerUser = value
	}
	for _, origin := range strings.Split(os.Getenv("REALTIME_ORIGINS"), ",") {
		origin = strings.TrimSpace(origin)
		if origin != "" {
			cfg.Origins[origin] = struct{}{}
		}
	}
	if strings.EqualFold(env("APP_ENV", "development"), "production") {
		if len(cfg.Origins) == 0 {
			return cfg, errors.New("REALTIME_ORIGINS is required in production")
		}
		if strings.TrimSpace(os.Getenv("REALTIME_REDIS_URL")) == "" {
			return cfg, errors.New("REALTIME_REDIS_URL is required in production")
		}
	}
	return cfg, nil
}

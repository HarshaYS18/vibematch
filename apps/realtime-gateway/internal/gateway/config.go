package gateway

import (
	"errors"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	ListenAddr             string
	AuthVerifyURL          string
	CapabilityKeyURL       string
	CapabilityIssuer       string
	CapabilityAudience     string
	CapabilityTokenVersion int
	CommandURL             string
	InboxCommandURL        string
	CommandTimeout         time.Duration
	RedisURL               string
	RedisPoolSize          int
	RedisPoolTimeout       time.Duration
	RedisReadTimeout       time.Duration
	RedisWriteTimeout      time.Duration
	NATSURL                string
	NATSInboxSubject       string
	NATSEnabled            bool
	NodeID                 string
	Origins                map[string]struct{}
	DrainTimeout           time.Duration
	AuthTimeout            time.Duration
	WriteTimeout           time.Duration
	PingInterval           time.Duration
	PongTimeout            time.Duration
	ReauthInterval         time.Duration
	LeaseTTL               time.Duration
	MaxMessageBytes        int64
	OutboundQueue          int
	MaxConnections         int64
	MaxConnectionsPerUser  int
	HotRoomSubscriberThreshold int
}

func env(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func positiveDurationEnv(key string, fallback time.Duration) (time.Duration, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback, nil
	}
	value, err := time.ParseDuration(raw)
	if err != nil || value <= 0 {
		return 0, errors.New(key + " must be a positive duration")
	}
	return value, nil
}

func positiveIntEnv(key string, fallback int) (int, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value <= 0 {
		return 0, errors.New(key + " must be positive")
	}
	return value, nil
}

func LoadConfig() (Config, error) {
	cfg := Config{
		ListenAddr:             env("REALTIME_LISTEN_ADDR", ":8081"),
		AuthVerifyURL:          strings.TrimSpace(os.Getenv("REALTIME_AUTH_VERIFY_URL")),
		CapabilityKeyURL:       strings.TrimSpace(os.Getenv("REALTIME_CAPABILITY_KEY_URL")),
		CapabilityIssuer:       env("REALTIME_CAPABILITY_ISSUER", "funkey-api"),
		CapabilityAudience:     env("REALTIME_CAPABILITY_AUDIENCE", "funkey-realtime"),
		CapabilityTokenVersion: 1,
		CommandURL:             strings.TrimSpace(os.Getenv("REALTIME_COMMAND_URL")),
		CommandTimeout:         3 * time.Second,
		RedisURL:               env("REALTIME_REDIS_URL", "redis://127.0.0.1:6379/0"),
		RedisPoolSize:          100,
		RedisPoolTimeout:       2 * time.Second,
		RedisReadTimeout:       2 * time.Second,
		RedisWriteTimeout:      2 * time.Second,
		NodeID:                 env("REALTIME_NODE_ID", env("HOSTNAME", "gateway-local")),
		Origins:                make(map[string]struct{}),
		DrainTimeout:           45 * time.Second,
		AuthTimeout:            3 * time.Second,
		WriteTimeout:           5 * time.Second,
		PingInterval:           20 * time.Second,
		PongTimeout:            60 * time.Second,
		ReauthInterval:         5 * time.Minute,
		LeaseTTL:               60 * time.Second,
		MaxMessageBytes:        16 * 1024,
		OutboundQueue:          64,
		MaxConnections:         10000,
		MaxConnectionsPerUser:  4,
		HotRoomSubscriberThreshold: 500,
	}
	cfg.NATSURL = strings.TrimSpace(os.Getenv("REALTIME_NATS_URL"))
	cfg.NATSEnabled = cfg.NATSURL != ""
	cfg.NATSInboxSubject = env(
		"REALTIME_NATS_INBOX_SUBJECT",
		"funkey.events.inbox.realtime",
	)
	if cfg.AuthVerifyURL == "" {
		return cfg, errors.New("REALTIME_AUTH_VERIFY_URL is required")
	}
	if cfg.CapabilityKeyURL == "" {
		cfg.CapabilityKeyURL = strings.TrimSuffix(cfg.AuthVerifyURL, "/verify") + "/capability-key"
	}
	if cfg.CommandURL == "" {
		cfg.CommandURL = strings.TrimSuffix(cfg.AuthVerifyURL, "/verify") + "/command"
	}
	cfg.InboxCommandURL = strings.TrimSpace(os.Getenv("REALTIME_INBOX_COMMAND_URL"))

	var err error
	if cfg.CapabilityTokenVersion, err = positiveIntEnv(
		"REALTIME_CAPABILITY_TOKEN_VERSION",
		cfg.CapabilityTokenVersion,
	); err != nil {
		return cfg, err
	}
	if cfg.CommandTimeout, err = positiveDurationEnv(
		"REALTIME_COMMAND_TIMEOUT",
		cfg.CommandTimeout,
	); err != nil {
		return cfg, err
	}
	if cfg.RedisPoolSize, err = positiveIntEnv("REALTIME_REDIS_POOL_SIZE", cfg.RedisPoolSize); err != nil {
		return cfg, err
	}
	if cfg.RedisPoolTimeout, err = positiveDurationEnv("REALTIME_REDIS_POOL_TIMEOUT", cfg.RedisPoolTimeout); err != nil {
		return cfg, err
	}
	if cfg.RedisReadTimeout, err = positiveDurationEnv("REALTIME_REDIS_READ_TIMEOUT", cfg.RedisReadTimeout); err != nil {
		return cfg, err
	}
	if cfg.RedisWriteTimeout, err = positiveDurationEnv("REALTIME_REDIS_WRITE_TIMEOUT", cfg.RedisWriteTimeout); err != nil {
		return cfg, err
	}
	if cfg.LeaseTTL, err = positiveDurationEnv("REALTIME_REDIS_LEASE_TTL", cfg.LeaseTTL); err != nil {
		return cfg, err
	}
	if cfg.DrainTimeout, err = positiveDurationEnv("REALTIME_DRAIN_TIMEOUT", cfg.DrainTimeout); err != nil {
		return cfg, err
	}
	if raw := os.Getenv("REALTIME_MAX_CONNECTIONS"); raw != "" {
		value, parseErr := strconv.ParseInt(raw, 10, 64)
		if parseErr != nil || value <= 0 {
			return cfg, errors.New("REALTIME_MAX_CONNECTIONS must be positive")
		}
		cfg.MaxConnections = value
	}
	if cfg.MaxConnectionsPerUser, err = positiveIntEnv("REALTIME_MAX_CONNECTIONS_PER_USER", cfg.MaxConnectionsPerUser); err != nil {
		return cfg, err
	}
	if cfg.HotRoomSubscriberThreshold, err = positiveIntEnv("REALTIME_HOT_ROOM_SUBSCRIBER_THRESHOLD", cfg.HotRoomSubscriberThreshold); err != nil {
		return cfg, err
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
		if cfg.InboxCommandURL == "" {
			return cfg, errors.New("REALTIME_INBOX_COMMAND_URL is required in production")
		}
		if !cfg.NATSEnabled {
			return cfg, errors.New("REALTIME_NATS_URL is required in production")
		}
		if strings.TrimSpace(cfg.NATSInboxSubject) == "" {
			return cfg, errors.New("REALTIME_NATS_INBOX_SUBJECT is required in production")
		}
	}
	return cfg, nil
}

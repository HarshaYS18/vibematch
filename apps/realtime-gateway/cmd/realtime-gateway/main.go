package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/HarshaYS18/vibematch/apps/realtime-gateway/internal/gateway"
	"github.com/redis/go-redis/v9"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	shutdownTelemetry, telemetryErr := gateway.SetupTelemetry(context.Background(), "funkey-realtime", logger)
	if telemetryErr != nil {
		logger.Error("telemetry setup failed; continuing without exporter", "error", telemetryErr)
	}
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		if err := shutdownTelemetry(ctx); err != nil {
			logger.Warn("telemetry shutdown failed", "error", err)
		}
	}()

	cfg, err := gateway.LoadConfig()
	if err != nil {
		logger.Error("invalid config", "error", err)
		os.Exit(1)
	}
	options, err := redis.ParseURL(cfg.RedisURL)
	if err != nil {
		logger.Error("invalid Redis URL", "error", err)
		os.Exit(1)
	}
	options.PoolSize = cfg.RedisPoolSize
	options.PoolTimeout = cfg.RedisPoolTimeout
	options.ReadTimeout = cfg.RedisReadTimeout
	options.WriteTimeout = cfg.RedisWriteTimeout
	options.ClientName = "funkey-realtime-" + cfg.NodeID
	client := redis.NewClient(options)
	defer client.Close()
	service := gateway.NewServer(
		cfg,
		gateway.NewHTTPAuthorizer(cfg.AuthVerifyURL, cfg.AuthTimeout),
		gateway.NewHTTPCommandExecutor(cfg.CommandURL, cfg.CommandTimeout),
		client,
		logger,
	)
	if err := service.Validate(); err != nil {
		logger.Error("invalid gateway", "error", err)
		os.Exit(1)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go service.ConsumeEvents(ctx)
	go service.Heartbeat(ctx)
	httpServer := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           service.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    16 * 1024,
	}
	go func() {
		logger.Info("realtime gateway listening", "addr", cfg.ListenAddr, "node_id", cfg.NodeID)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("http server failed", "error", err)
			os.Exit(1)
		}
	}()
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)
	<-signals
	logger.Info("gateway draining")
	service.Drain(context.Background())
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()
	_ = httpServer.Shutdown(shutdownCtx)
	service.DeleteNodeLease(context.Background())
	cancel()
	logger.Info("gateway stopped")
}

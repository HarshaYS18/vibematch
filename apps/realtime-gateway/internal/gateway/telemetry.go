package gateway

import (
	"context"
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	sdkresource "go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

func telemetryEnabled() bool {
	value := strings.TrimSpace(strings.ToLower(os.Getenv("OTEL_TRACES_ENABLED")))
	return value == "1" || value == "true" || value == "yes"
}

// SetupTelemetry configures a bounded asynchronous OTLP exporter. Callers treat
// any setup/export error as diagnostic only; business readiness never depends
// on an observability backend.
func SetupTelemetry(ctx context.Context, serviceName string, logger *slog.Logger) (func(context.Context) error, error) {
	otel.SetTextMapPropagator(
		propagation.NewCompositeTextMapPropagator(
			propagation.TraceContext{},
			propagation.Baggage{},
		),
	)
	if !telemetryEnabled() {
		return func(context.Context) error { return nil }, nil
	}

	endpoint := strings.TrimSpace(os.Getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"))
	if endpoint == "" {
		endpoint = "http://127.0.0.1:4318/v1/traces"
	}
	timeout := 3 * time.Second
	if raw := strings.TrimSpace(os.Getenv("OTEL_EXPORT_TIMEOUT_SECONDS")); raw != "" {
		if parsed, err := strconv.ParseFloat(raw, 64); err == nil && parsed > 0 {
			timeout = time.Duration(parsed * float64(time.Second))
		}
	}
	ratio := 0.10
	if raw := strings.TrimSpace(os.Getenv("OTEL_TRACE_SAMPLE_RATIO")); raw != "" {
		if parsed, err := strconv.ParseFloat(raw, 64); err == nil && parsed >= 0 && parsed <= 1 {
			ratio = parsed
		}
	}

	exporter, err := otlptracehttp.New(
		ctx,
		otlptracehttp.WithEndpointURL(endpoint),
		otlptracehttp.WithTimeout(timeout),
	)
	if err != nil {
		return func(context.Context) error { return nil }, err
	}
	resource := sdkresource.NewSchemaless(
		attribute.String("service.name", serviceName),
		attribute.String("service.namespace", "funkey"),
		attribute.String("deployment.environment", env("APP_ENV", "development")),
	)
	provider := sdktrace.NewTracerProvider(
		sdktrace.WithResource(resource),
		sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(ratio))),
		sdktrace.WithBatcher(
			exporter,
			sdktrace.WithMaxQueueSize(2048),
			sdktrace.WithMaxExportBatchSize(512),
			sdktrace.WithBatchTimeout(5*time.Second),
			sdktrace.WithExportTimeout(timeout),
		),
	)
	otel.SetTracerProvider(provider)
	logger.Info("OpenTelemetry tracing enabled", "service", serviceName, "endpoint", endpoint)
	return provider.Shutdown, nil
}

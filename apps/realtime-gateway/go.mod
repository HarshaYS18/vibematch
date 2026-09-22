module github.com/HarshaYS18/vibematch/apps/realtime-gateway

go 1.27

require (
	github.com/alicebob/miniredis/v2 v2.39.0
	github.com/gorilla/websocket v1.5.3
	github.com/redis/go-redis/v9 v9.22.0
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.71.0
	go.opentelemetry.io/otel v1.46.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp v1.46.0
	go.opentelemetry.io/otel/sdk v1.46.0
)

require (
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/yuin/gopher-lua v1.1.1 // indirect
	go.uber.org/atomic v1.11.0 // indirect
	golang.org/x/sys v0.30.0 // indirect
)

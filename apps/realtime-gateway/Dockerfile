FROM golang:1.27.1-bookworm AS build
WORKDIR /src
COPY apps/realtime-gateway/go.mod apps/realtime-gateway/go.sum ./
RUN go mod download
COPY apps/realtime-gateway/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/realtime-gateway ./cmd/realtime-gateway

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/realtime-gateway /realtime-gateway
USER nonroot:nonroot
EXPOSE 8081
ENTRYPOINT ["/realtime-gateway"]

"""OpenTelemetry bootstrap and trace-context helpers for Python services.

Telemetry is deliberately fail-open: exporters are bounded and never participate
in business correctness, readiness, or transaction commit decisions.
"""

from contextlib import contextmanager
import logging
from typing import Iterator, Mapping

from fastapi import FastAPI
from opentelemetry import propagate, trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased
from opentelemetry.trace import SpanKind

from app.core.config import settings


_logger = logging.getLogger("funkey.telemetry")
_provider: TracerProvider | None = None
_fastapi_apps: set[int] = set()
_sqlalchemy_engines: set[int] = set()
_redis_instrumented = False


def configure_telemetry(
    service_name: str,
    *,
    app: FastAPI | None = None,
    engine=None,
) -> TracerProvider | None:
    """Configure bounded OTLP tracing when explicitly enabled."""
    global _provider, _redis_instrumented

    if not settings.OTEL_TRACES_ENABLED:
        return None

    if _provider is None:
        sampler_ratio = min(1.0, max(0.0, settings.OTEL_TRACE_SAMPLE_RATIO))
        provider = TracerProvider(
            resource=Resource.create({
                "service.name": service_name,
                "service.namespace": "funkey",
                "deployment.environment": settings.APP_ENV,
            }),
            sampler=ParentBased(TraceIdRatioBased(sampler_ratio)),
        )
        exporter = OTLPSpanExporter(
            endpoint=settings.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT,
            timeout=settings.OTEL_EXPORT_TIMEOUT_SECONDS,
        )
        provider.add_span_processor(
            BatchSpanProcessor(
                exporter,
                max_queue_size=settings.OTEL_BSP_MAX_QUEUE_SIZE,
                max_export_batch_size=settings.OTEL_BSP_MAX_EXPORT_BATCH_SIZE,
                schedule_delay_millis=settings.OTEL_BSP_SCHEDULE_DELAY_MS,
                export_timeout_millis=int(settings.OTEL_EXPORT_TIMEOUT_SECONDS * 1000),
            )
        )
        trace.set_tracer_provider(provider)
        _provider = provider
        _logger.info("OpenTelemetry tracing enabled for %s", service_name)

    if app is not None and id(app) not in _fastapi_apps:
        FastAPIInstrumentor.instrument_app(
            app,
            tracer_provider=_provider,
            excluded_urls="/live,/ready,/metrics,/health",
        )
        _fastapi_apps.add(id(app))

    if engine is not None and id(engine) not in _sqlalchemy_engines:
        SQLAlchemyInstrumentor().instrument(
            engine=engine,
            tracer_provider=_provider,
            enable_commenter=False,
        )
        _sqlalchemy_engines.add(id(engine))

    if not _redis_instrumented:
        RedisInstrumentor().instrument(tracer_provider=_provider)
        _redis_instrumented = True

    return _provider


def shutdown_telemetry() -> None:
    """Flush best-effort telemetry without making shutdown correctness depend on it."""
    global _provider
    provider = _provider
    _provider = None
    if provider is None:
        return
    try:
        provider.force_flush(timeout_millis=2000)
        provider.shutdown()
    except Exception:
        _logger.exception("OpenTelemetry shutdown failed")


def current_trace_id() -> str | None:
    context = trace.get_current_span().get_span_context()
    if not context.is_valid:
        return None
    return f"{context.trace_id:032x}"


def current_traceparent() -> str | None:
    context = trace.get_current_span().get_span_context()
    if not context.is_valid:
        return None
    return (
        f"00-{context.trace_id:032x}-{context.span_id:016x}-"
        f"{int(context.trace_flags) & 0xff:02x}"
    )


def extract_trace_context(traceparent: str | None):
    if not traceparent:
        return None
    return propagate.extract({"traceparent": traceparent})


@contextmanager
def traced(
    name: str,
    *,
    traceparent: str | None = None,
    kind: SpanKind = SpanKind.INTERNAL,
    attributes: Mapping[str, str | int | float | bool] | None = None,
) -> Iterator[trace.Span]:
    tracer = trace.get_tracer("funkey.python")
    parent = extract_trace_context(traceparent)
    with tracer.start_as_current_span(
        name,
        context=parent,
        kind=kind,
        attributes=dict(attributes or {}),
    ) as span:
        yield span

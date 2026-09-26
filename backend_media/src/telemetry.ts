import {
  ROOT_CONTEXT,
  SpanKind,
  SpanStatusCode,
  context,
  propagation,
  trace,
  type Attributes,
} from '@opentelemetry/api';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { config } from './config.js';

let sdk: NodeSDK | undefined;

export function startMediaTelemetry(): void {
  if (!config.telemetry.enabled || sdk) return;
  try {
    sdk = new NodeSDK({
      serviceName: 'funkey-media',
      traceExporter: new OTLPTraceExporter({
        url: config.telemetry.tracesEndpoint,
        timeoutMillis: config.telemetry.exportTimeoutMs,
        concurrencyLimit: 4,
      }),
    });
    sdk.start();
    console.info('[media] OpenTelemetry tracing enabled');
  } catch (error) {
    sdk = undefined;
    console.error('[media] telemetry setup failed; continuing without exporter', error);
  }
}

export async function shutdownMediaTelemetry(): Promise<void> {
  const current = sdk;
  sdk = undefined;
  if (!current) return;
  try {
    await current.shutdown();
  } catch (error) {
    console.error('[media] telemetry shutdown failed', error);
  }
}

export async function withMediaSpan<T>(
  name: string,
  handler: () => Promise<T>,
  traceparent?: string,
  attributes: Attributes = {},
): Promise<T> {
  const parent = traceparent
    ? propagation.extract(ROOT_CONTEXT, { traceparent })
    : context.active();
  const tracer = trace.getTracer('funkey.media');
  return context.with(parent, () =>
    tracer.startActiveSpan(
      name,
      { kind: SpanKind.INTERNAL, attributes },
      async (span) => {
        try {
          const result = await handler();
          span.setStatus({ code: SpanStatusCode.OK });
          return result;
        } catch (error) {
          span.recordException(error instanceof Error ? error : String(error));
          span.setStatus({
            code: SpanStatusCode.ERROR,
            message: error instanceof Error ? error.message : String(error),
          });
          throw error;
        } finally {
          span.end();
        }
      },
    ),
  );
}

export function injectTraceHeaders(
  headers: Record<string, string>,
): Record<string, string> {
  const carrier = { ...headers };
  propagation.inject(context.active(), carrier);
  return carrier;
}

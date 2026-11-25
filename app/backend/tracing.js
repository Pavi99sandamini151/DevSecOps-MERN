// OpenTelemetry traces only (metrics stay on prom-client :9090).
// Loaded via: node -r ./tracing.js index.js  OR  require before app boot.

const { NodeSDK } = require("@opentelemetry/sdk-node");
const { getNodeAutoInstrumentations } = require("@opentelemetry/auto-instrumentations-node");
const { OTLPTraceExporter } = require("@opentelemetry/exporter-trace-otlp-http");
const { Resource } = require("@opentelemetry/resources");
const { ATTR_SERVICE_NAME } = require("@opentelemetry/semantic-conventions");

const endpoint =
  process.env.OTEL_EXPORTER_OTLP_ENDPOINT ||
  "http://otel-collector.monitoring.svc.cluster.local:4318";

const sdk = new NodeSDK({
  resource: new Resource({
    [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || "backend",
  }),
  traceExporter: new OTLPTraceExporter({
    url: `${endpoint.replace(/\/$/, "")}/v1/traces`,
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      "@opentelemetry/instrumentation-fs": { enabled: false },
    }),
  ],
});

sdk.start();

process.on("SIGTERM", () => {
  sdk
    .shutdown()
    .catch((err) => console.error("OTel shutdown error", err))
    .finally(() => process.exit(0));
});

module.exports = sdk;

## otel.nim -- OpenTelemetry tracing and metrics. Re-export module.
{.experimental: "strict_funcs".}
import telemetry/[span, meter, context, export_stdout, export_otlp, breach]
export span, meter, context, export_stdout, export_otlp, breach

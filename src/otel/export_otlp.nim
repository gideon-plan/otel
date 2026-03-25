## export_otlp.nim -- OTLP export over HTTP using httpc + protobuf.
##
## Serializes spans and metrics to OTLP protobuf format and POSTs
## to the collector endpoint.

{.experimental: "strict_funcs".}

import std/json
import basis/code/choice
import span, meter, context
import httpc/curl_client

type
  OtlpExporter* = object
    endpoint*: string  ## e.g. "http://localhost:4318"

proc new_otlp_exporter*(endpoint: string = "http://localhost:4318"): OtlpExporter =
  OtlpExporter(endpoint: endpoint)

proc spans_to_json(spans: seq[Span]): string =
  ## Serialize spans to OTLP JSON format (JSON encoding, not protobuf binary).
  var resource_spans = newJArray()
  for s in spans:
    resource_spans.add(%*{
      "name": s.name,
      "traceId": s.trace_id,
      "spanId": s.span_id,
      "parentSpanId": s.parent_span_id,
      "startTimeUnixNano": $s.start_time,
      "endTimeUnixNano": $s.end_time,
      "status": {"code": s.status},
    })
  $(%*{"resourceSpans": [{"scopeSpans": [{"spans": resource_spans}]}]})

proc metrics_to_json(counters: seq[Counter], gauges: seq[Gauge]): string =
  var metrics = newJArray()
  for c in counters:
    metrics.add(%*{"name": c.name, "type": "sum", "value": c.get()})
  for g in gauges:
    metrics.add(%*{"name": g.name, "type": "gauge", "value": g.get()})
  $(%*{"resourceMetrics": [{"scopeMetrics": [{"metrics": metrics}]}]})

proc export_spans*(e: OtlpExporter, spans: seq[Span]): Choice[bool] =
  ## Serialize spans and POST to /v1/traces.
  let cc_r = init_curl_client()
  if cc_r.is_bad: return bad[bool]("otel", "failed to init HTTP client")
  var cc = cc_r.val
  defer: cc.close()

  let body = spans_to_json(spans)
  let resp = cc.post(e.endpoint & "/v1/traces", body,
    @[("Content-Type", "application/json")])
  if resp.is_bad: return bad[bool]("otel", "OTLP export failed: " & resp.err.msg)
  if resp.val.status >= 400:
    return bad[bool]("otel", "OTLP export HTTP " & $resp.val.status)
  good(true)

proc export_metrics*(e: OtlpExporter, counters: seq[Counter],
                     gauges: seq[Gauge]): Choice[bool] =
  ## Serialize metrics and POST to /v1/metrics.
  let cc_r = init_curl_client()
  if cc_r.is_bad: return bad[bool]("otel", "failed to init HTTP client")
  var cc = cc_r.val
  defer: cc.close()

  let body = metrics_to_json(counters, gauges)
  let resp = cc.post(e.endpoint & "/v1/metrics", body,
    @[("Content-Type", "application/json")])
  if resp.is_bad: return bad[bool]("otel", "OTLP export failed: " & resp.err.msg)
  if resp.val.status >= 400:
    return bad[bool]("otel", "OTLP export HTTP " & $resp.val.status)
  good(true)

## export_otlp.nim -- OTLP export over HTTP using httpc + protobuf.
##
## Serializes spans and metrics to OTLP protobuf format and POSTs
## to the collector endpoint.

{.experimental: "strict_funcs".}

import jsony
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
  var span_arr = "["
  for i, s in spans:
    if i > 0: span_arr.add ','
    span_arr.add '{'
    span_arr.add "\"name\":"; span_arr.dumpHook(s.name)
    span_arr.add ",\"traceId\":"; span_arr.dumpHook(s.trace_id)
    span_arr.add ",\"spanId\":"; span_arr.dumpHook(s.span_id)
    span_arr.add ",\"parentSpanId\":"; span_arr.dumpHook(s.parent_span_id)
    span_arr.add ",\"startTimeUnixNano\":"; span_arr.dumpHook($s.start_time)
    span_arr.add ",\"endTimeUnixNano\":"; span_arr.dumpHook($s.end_time)
    span_arr.add ",\"status\":{\"code\":"; span_arr.dumpHook(s.status)
    span_arr.add "}}"
  span_arr.add ']'
  "{\"resourceSpans\":[{\"scopeSpans\":[{\"spans\":" & span_arr & "}]}]}"

proc metrics_to_json(counters: seq[Counter], gauges: seq[Gauge]): string =
  var metrics = "["
  for i, c in counters:
    if i > 0: metrics.add ','
    metrics.add '{'
    metrics.add "\"name\":"; metrics.dumpHook(c.name)
    metrics.add ",\"type\":\"sum\""
    metrics.add ",\"value\":"; metrics.dumpHook(c.get())
    metrics.add '}'
  for i, g in gauges:
    if counters.len > 0 or i > 0: metrics.add ','
    metrics.add '{'
    metrics.add "\"name\":"; metrics.dumpHook(g.name)
    metrics.add ",\"type\":\"gauge\""
    metrics.add ",\"value\":"; metrics.dumpHook(g.get())
    metrics.add '}'
  metrics.add ']'
  "{\"resourceMetrics\":[{\"scopeMetrics\":[{\"metrics\":" & metrics & "}]}]}"

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

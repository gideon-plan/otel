## totel.nim -- Tests for OpenTelemetry tracing and metrics.
{.experimental: "strict_funcs".}
import std/[unittest, strutils, tables]
import basis/code/choice
import telemetry

suite "span":
  test "create and finish span":
    let s = new_span("test-op", "aabbccdd" & "aabbccdd" & "aabbccdd" & "aabbccdd",
                     "11223344" & "11223344")
    check s.name == "test-op"
    check s.status == SpanStatus.Unset
    s.finish()
    check s.duration_ms >= 0.0

  test "set attributes":
    let s = new_span("op", "t" & "0".repeat(31), "s" & "0".repeat(15))
    s.set_attribute("http.method", "GET")
    check s.attributes["http.method"] == "GET"

  test "add event":
    let s = new_span("op", "t" & "0".repeat(31), "s" & "0".repeat(15))
    s.add_event("exception")
    check s.events.len == 1
    check s.events[0].name == "exception"

  test "set status":
    let s = new_span("op", "t" & "0".repeat(31), "s" & "0".repeat(15))
    s.set_status(SpanStatus.Error, "timeout")
    check s.status == SpanStatus.Error
    check s.status_message == "timeout"

suite "meter":
  test "counter":
    var c = new_counter("requests")
    c.add(1)
    c.add(5)
    check c.get() == 6

  test "gauge":
    var g = new_gauge("connections")
    g.set(42)
    check g.get() == 42
    g.set(10)
    check g.get() == 10

  test "histogram":
    var h = new_histogram("latency", @[10.0, 50.0, 100.0, 500.0])
    h.record(5.0)
    h.record(75.0)
    h.record(200.0)
    check h.count == 3
    check abs(h.sum - 280.0) < 0.01
    check h.buckets[0].count == 1  # 5 <= 10

suite "context":
  test "parse traceparent":
    let result = parse_traceparent("00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01")
    check result.is_good
    check result.val.version == 0
    check result.val.trace_id == "0af7651916cd43dd8448eb211c80319c"
    check result.val.parent_id == "b7ad6b7169203331"
    check result.val.flags == 1
    check is_sampled(result.val)

  test "format traceparent round-trip":
    let ctx = new_trace_context("0af7651916cd43dd8448eb211c80319c", "b7ad6b7169203331")
    let formatted = format_traceparent(ctx)
    check formatted == "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
    let parsed = parse_traceparent(formatted)
    check parsed.is_good
    check parsed.val.trace_id == ctx.trace_id

  test "invalid traceparent":
    let result = parse_traceparent("invalid")
    check result.is_bad

suite "export_stdout":
  test "format counter":
    let e = new_stdout_exporter()
    var c = new_counter("test")
    c.add(10)
    let text = e.format_counter(c)
    check text.contains("\"name\":\"test\"")
    check text.contains("\"value\":10")

  test "format span":
    let e = new_stdout_exporter()
    let s = new_span("op", "t" & "0".repeat(31), "s" & "0".repeat(15))
    s.finish()
    let text = e.format_span(s)
    check text.contains("\"name\":\"op\"")

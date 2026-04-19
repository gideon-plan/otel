## span.nim -- Trace spans with context propagation.

{.experimental: "strict_funcs".}

import std/[times, tables]


type
  SpanStatus* {.pure.} = enum
    Unset, Ok, Error

  SpanKind* {.pure.} = enum
    Internal, Server, Client, Producer, Consumer

  Span* = ref object
    trace_id*: string       ## 16-byte hex
    span_id*: string        ## 8-byte hex
    parent_span_id*: string ## 8-byte hex or ""
    name*: string
    kind*: SpanKind
    start_time*: DateTime
    end_time*: DateTime
    status*: SpanStatus
    status_message*: string
    attributes*: Table[string, string]
    events*: seq[SpanEvent]

  SpanEvent* = object
    name*: string
    created*: DateTime
    attributes*: Table[string, string]

proc new_span*(name: string, trace_id, span_id: string,
               parent: string = "", kind: SpanKind = SpanKind.Internal): Span =
  Span(name: name, trace_id: trace_id, span_id: span_id,
       parent_span_id: parent, kind: kind,
       start_time: now(), status: SpanStatus.Unset)

proc finish*(s: Span) =
  s.end_time = now()

proc set_status*(s: Span, status: SpanStatus, message: string = "") =
  s.status = status; s.status_message = message

proc set_attribute*(s: Span, key, value: string) =
  s.attributes[key] = value

proc add_event*(s: Span, name: string, attrs: Table[string, string] = initTable[string, string]()) =
  s.events.add(SpanEvent(name: name, created: now(), attributes: attrs))

proc duration_ms*(s: Span): float =
  let d = s.end_time - s.start_time
  float(d.inMilliseconds)

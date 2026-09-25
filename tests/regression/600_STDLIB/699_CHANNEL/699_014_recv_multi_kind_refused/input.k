// std/channel — `recv` can't spell one payload type on a multi-kind
// channel; consumers arm per kind. The refusal points at the `!` join.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
}

std/proto(Alert) {
    level: u64
}

std/channel:new(wire, capacity: 8) { reading: Reading, alert: Alert }

std/channel:recv(wire)
| some v |> std/io:print.ln("{{ v:s }}")
| none |> std/io:print.ln("none")
| closed |> std/io:print.ln("closed")

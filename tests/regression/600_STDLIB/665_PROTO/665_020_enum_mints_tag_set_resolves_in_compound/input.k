// PINS: `std/types:enum` mints a closed tag set as a nominal terminal — the
// name resolves as a compound field type (`level: ThreatLevel`), a tag
// spells `ThreatLevel.high` at a use site, and `{{ level:t }}` prints the
// tag name through a list projection.
import std/io
import std/types
import std/proto
import std/list

std/types:enum(ThreatLevel) {
    low,
    medium,
    high,
    critical
}

std/proto(Session) {
    ip: string,
    score: i64,
    level: ThreatLevel
}

std/list:new(Session)
| list xs |> std/list:push(xs, ip: "10.0.0.7", score: 7, level: ThreatLevel.high) |> std/list:get(xs, i: 0)
    | item s |> std/io:print.ln("{{ s.ip:s }} {{ s.score:d }} {{ s.level:t }}") |> std/list:free(xs)
    | out-of-bounds |> std/io:print.ln("oob") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")

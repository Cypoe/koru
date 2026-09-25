// std/rings — a proto-typed element rides the ring by value. The `{ }`
// body is the same declaration grammar a proto speaks: `name: Type`
// entries. A ring holds exactly one; the word names the element in
// diagnostics and generated units. `dequeue | some r` binds the whole
// proto — field deconstruction happens in Koru after the take.
import std/proto
import std/rings
import std/io

std/proto(Reading) {
    id: u64
    ts: f64
}

pub tor mk-reading { i: u64, t: f64 } -> Reading
mk-reading -> { id: i, ts: t }

std/rings:new(feed, capacity: 8) { reading: Reading }

mk-reading(i: 7, t: 2.5): r |> std/rings:enqueue(feed, v: r)
| ok |> std/rings:dequeue(feed)
    | some v |> std/io:print.ln("got {{ v.id:d }} {{ v.ts:f }}")
    | none |> std/io:print.ln("ERROR: empty")
| full |> std/io:print.ln("ERROR: full")

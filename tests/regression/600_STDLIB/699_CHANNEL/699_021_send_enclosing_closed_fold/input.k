// OWED: the enclosing-arm claim on a channel `closed`. The inner
// `std/channel:send` fires `closed` (channel was closed under `| ok`), no
// arm at its level; the close level carries only `| ok`, so the nearest
// enclosing same-named arm is the outer send's `| closed` — it must claim
// the inner variant. Channel member of the 320_120 / 320_170 fold family.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
    ts: f64
}

pub tor mk-reading { i: u64, t: f64 } -> Reading
mk-reading -> { id: i, ts: t }

std/channel:new(inbox, capacity: 4) { reading: Reading }

mk-reading(i: 1, t: 1.0): a |> std/channel:send(inbox, a)
| ok |> std/channel:close(inbox)
    | ok |> mk-reading(i: 2, t: 2.0): b |> std/channel:send(inbox, b)
        | ok |> std/io:print.ln("sent")
        | full |> std/io:print.ln("inner full")
| full |> std/io:print.ln("outer full")
| closed |> std/io:print.ln("outer closed")

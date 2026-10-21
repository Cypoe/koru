// std/rings x std/supervisor — RULED 2026-10-21: the direct joint is
// refused by design. Supervising the `std/rings` verb itself —
// `| full |> supervised | retry t |> std/rings:enqueue(feed, v: x)` —
// refuses: v1 supervises same-module children only (`KORU161`), and the
// generated retry step would carry a transform-tor call into generated
// code either way. The ruling is that composition onto a std verb
// happens through a named wrapper tor — where the retry policy gets
// spelled — not by relaxing KORU161 for a cross-module contract nobody
// named locally. The wrapper shape is 320_110's; this pin documents the
// boundary as intended.
import std/rings
import std/supervisor
import std/io

std/rings:new(feed, capacity: 2) { value: u64 }

pub tor push { x: u64 }
| ok
| full

push = std/rings:enqueue(feed, v: x)
| ok => ok
| full |> std/supervisor:supervised
    | retry t when t < 2 |> std/rings:enqueue(feed, v: x)
    | exhausted => full

std/rings:enqueue(feed, v: 1)
| ok |> std/rings:enqueue(feed, v: 2)
    | ok |> push(x: 3)
        | ok |> std/io:print.ln("in")
        | full |> std/io:print.ln("gave up")
    | full |> std/io:print.ln("ERROR: second enqueue")
| full |> std/io:print.ln("ERROR: first enqueue")

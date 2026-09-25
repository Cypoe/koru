// std/rings x std/supervisor — OWED: the direct joint. Supervising the
// `std/rings` verb itself — `| full |> supervised | retry t |>
// std/rings:enqueue(feed, v: x)` — refuses today: v1 supervises
// same-module children only (`KORU161`), and the generated retry step
// would carry a transform-tor call into generated code either way. When
// supervision can reach across module lines (or channel/rings ops expose
// same-module generated children), this pin flips green. Until then the
// wrapper shape is 320_110's.
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

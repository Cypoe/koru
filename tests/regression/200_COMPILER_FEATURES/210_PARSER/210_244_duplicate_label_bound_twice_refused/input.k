// PINS: a call binds each name once. `mk(a: 41, a: 37)` hands the same
// parameter two values — one silently wins downstream (measured last-wins
// 2026-09-24: store:new(dogs, capacity: 64, capacity: 32) minted a 32-slot
// store with no diagnostic). This is the labeled twin of the silent drop
// PARSE006 walls on the bare side — refuse it the same way.
import std/io

tor mk { a: i64 } -> i64
mk = a

mk(a: 41, a: 37): v |> std/io:print.ln("{{ v:d }}")

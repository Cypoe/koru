// PIN (2026-09-18): a non-tail self-call whose continuation re-enters the same
// event lowers to flat continuation segments — the emitter must produce
// __koru_seg_eval + __koru_seg_kN over a uniform-width lane stack instead of a
// native recursive call. The chained shape (a self-call's result feeds the
// next self-call, ending in a tail self-forward) is what selects the path; a
// combining continuation like fib's `a + b` does not (320_149 pins the other
// side of the boundary).
//
// ack(2,3) = 9 exercises: the eval segment, one continuation segment (the
// `inner` bind feeding `ack(m-1, inner)`), the done sentinel, and the nested
// tail self-forward on the n == 0 arm. post.sh pins the emitted symbols.
import std/io

pub tor ack { m: i64, n: i64 } -> i64

ack = if(m == 0)
| then -> n + 1
| else |> if(n == 0)
    | then |> ack(m: m - 1, n: 1): v -> v
    | else |> ack(m, n: n - 1): inner |> ack(m: m - 1, n: inner): v -> v

ack(m: 2, n: 3): r |> std/io:print.ln("{{ r:d }}")

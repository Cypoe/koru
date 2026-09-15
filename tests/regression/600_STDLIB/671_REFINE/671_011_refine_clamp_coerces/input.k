// Test: `clamp(lo, hi)` is a normalizer term, not a bound — the boundary
// silently saturates the value into range instead of refusing it. Push
// `gain: 240` and the stored record holds 100; push `gain: -50` and it
// holds 0. No `?!violated` fires: the declaration spells the policy, so
// the coercion is the type doing exactly what it says.
//
// Expected: runs clean — `gain 0` then `gain 100` (pop order), the two
//           out-of-range writes stored as their nearest clamp bound.
import std/proto
import std/refine
import std/list
import std/io

std/proto(Mixer) {
    gain: i64
}

std/refine(Mixer) {
    gain: i64 & clamp(0, 100)
}

std/list:new(Mixer)
| list xs |> std/list:push(xs, gain: 240) |> std/list:push(xs, gain: -50)
    |> std/list:pop(xs)
    | item m |> std/io:print.ln("gain {{ m.gain:d }}") |> std/list:pop(xs)
        | item m2 |> std/io:print.ln("gain {{ m2.gain:d }}") |> std/list:free(xs)
        | empty |> std/io:print.ln("empty") |> std/list:free(xs)
    | empty |> std/io:print.ln("empty") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")

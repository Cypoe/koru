// Test: clamps meet like bounds do — two refine blocks each declare a
// `clamp`, and the field's normalizer is their intersection
// ([0,100] ∩ [10,90] = [10,90]), order-independent, never last-wins.
// Push `gain: 5` stores 10; push `gain: 95` stores 90.
//
// Expected: runs clean — `gain 10` then `gain 90` (the met interval's
//           edges, both writes saturated inward).
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

std/refine(Mixer) {
    gain: i64 & clamp(10, 90)
}

std/list:new(Mixer)
| list xs |> std/list:push(xs, gain: 5) |> std/list:push(xs, gain: 95)
    |> std/list:pop(xs)
    | item m |> std/io:print.ln("gain {{ m.gain:d }}") |> std/list:pop(xs)
        | item m2 |> std/io:print.ln("gain {{ m2.gain:d }}") |> std/list:free(xs)
        | empty |> std/io:print.ln("empty") |> std/list:free(xs)
    | empty |> std/io:print.ln("empty") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")

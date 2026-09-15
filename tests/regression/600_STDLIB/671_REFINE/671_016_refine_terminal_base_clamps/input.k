// Test: clamp on a terminal-typed field — `gain: Gain` where Gain minted by
// `std/proto:i64(Gain)` saturates at the boundary exactly as an i64 field
// would. The terminal resolves to its host scalar for legality, then the
// write coerces: 240 stores 100, -50 stores 0.
//
// Expected: runs clean — `gain 0` then `gain 100` (pop order).
import std/proto
import std/refine
import std/list
import std/io

std/proto:i64(Gain)

std/proto(Mixer) {
    gain: Gain
}

std/refine(Mixer) {
    gain: Gain & clamp(0, 100)
}

std/list:new(Mixer)
| list xs |> std/list:push(xs, gain: 240) |> std/list:push(xs, gain: -50)
    |> std/list:pop(xs)
    | item m |> std/io:print.ln("gain {{ m.gain:d }}") |> std/list:pop(xs)
        | item m2 |> std/io:print.ln("gain {{ m2.gain:d }}") |> std/list:free(xs)
        | empty |> std/io:print.ln("empty") |> std/list:free(xs)
    | empty |> std/io:print.ln("empty") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")

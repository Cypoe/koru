// Test: normalize first, then check — a field carrying BOTH `clamp` and a
// bound stores the saturated value, and the bound judges what was stored.
// `clamp(0,100) & >=10`: push `gain: 5` writes 5 (in clamp range) which
// fails `>=10` — the `?!violated` arm fires and the caller supervises.
// Push `gain: 50` meets both terms and lands.
//
// Expected: runs clean — `rejected gain` then `stored 50`.
import std/proto
import std/refine
import std/list
import std/io

std/proto(Mixer) {
    gain: i64
}

std/refine(Mixer) {
    gain: i64 & clamp(0, 100) & >=10
}

std/list:new(Mixer)
| list xs |> std/list:push(xs, gain: 5)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:push(xs, gain: 50) |> std/list:pop(xs)
        | item m |> std/io:print.ln("stored {{ m.gain:d }}") |> std/list:free(xs)
        | empty |> std/io:print.ln("empty") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")

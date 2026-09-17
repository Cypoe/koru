// Test: a set that lands on ONE value IS that equality. `5 | 7` filtered
// by `>6` leaves `7` alone, and the canonical form is `==7` — one lattice
// element with one spelling, so nothing downstream has to know that a
// singleton set and an equality are the same thing.
//
// Expected: Stage C prints `==7` (expected_comptime); runtime prints
//           `rejected mode` for 5 then `accepted` for 7.
import std/proto
import std/refine
import std/list
import std/io

std/proto(Sample) {
    mode: i64
}

std/refine(Sample) {
    mode: i64 & 5 | 7 & >6
}

std/list:new(Sample)
| list xs |> std/list:push(xs, mode: 5)
    | ok |> std/io:print.ln("accepted-wrong") |> std/list:free(xs)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR")

std/list:new(Sample)
| list ys |> std/list:push(ys, mode: 7)
    | ok |> std/io:print.ln("accepted") |> std/list:free(ys)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:free(ys)
| err e |> std/io:print.ln("ERR")

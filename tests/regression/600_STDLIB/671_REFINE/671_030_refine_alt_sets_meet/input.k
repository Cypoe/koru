// Test: two sets meet by INTERSECTION — the same confluence every other
// term has. `1 | 2 | 3` met with `2 | 3 | 4` is `2 | 3`, whichever block
// the transform reaches first, and a value only one block allowed is
// refused.
//
// Expected: Stage C prints `2 | 3` (expected_comptime); runtime prints
//           `accepted` then `rejected mode`.
import std/proto
import std/refine
import std/list
import std/io

std/proto(Sample) {
    mode: i64
}

std/refine(Sample) {
    mode: i64 & 1 | 2 | 3
}

std/refine(Sample) {
    mode: i64 & 2 | 3 | 4
}

std/list:new(Sample)
| list xs |> std/list:push(xs, mode: 3)
    | ok |> std/io:print.ln("accepted") |> std/list:free(xs)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR")

std/list:new(Sample)
| list ys |> std/list:push(ys, mode: 1)
    | ok |> std/io:print.ln("accepted-wrong") |> std/list:free(ys)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:free(ys)
| err e |> std/io:print.ln("ERR")

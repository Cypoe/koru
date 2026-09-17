// Test: the field's other terms filter the set — a member the bounds
// exclude is not reachable, so the canonical meet lists only what is. The
// declared `1` is dropped by `>1`: the guard judges the intersection, not
// the set as written.
//
// Expected: Stage C prints `>1 & 2 | 3` (expected_comptime); runtime
//           prints `rejected mode` for 1 then `accepted` for 3.
import std/proto
import std/refine
import std/list
import std/io

std/proto(Sample) {
    mode: i64
}

std/refine(Sample) {
    mode: i64 & 1 | 2 | 3 & >1
}

std/list:new(Sample)
| list xs |> std/list:push(xs, mode: 1)
    | ok |> std/io:print.ln("accepted-wrong") |> std/list:free(xs)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR")

std/list:new(Sample)
| list ys |> std/list:push(ys, mode: 3)
    | ok |> std/io:print.ln("accepted") |> std/list:free(ys)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:free(ys)
| err e |> std/io:print.ln("ERR")

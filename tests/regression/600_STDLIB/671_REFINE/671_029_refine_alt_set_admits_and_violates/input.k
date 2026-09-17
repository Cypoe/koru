// Test: the disjunction atom — `1 | 2 | 3` is a set of alternatives, the
// sixth term kind. It meets like every other term and is enforced at the
// boundary: a member is admitted, a non-member is refused by name.
//
// Expected: Stage C prints the canonical meet (expected_comptime); runtime
//           prints `accepted` then `rejected mode`.
import std/proto
import std/refine
import std/list
import std/io

std/proto(Sample) {
    mode: i64
    label: string
}

std/refine(Sample) {
    mode: i64 & 1 | 2 | 3
    label: string
}

std/list:new(Sample)
| list xs |> std/list:push(xs, mode: 2, label: "a")
    | ok |> std/io:print.ln("accepted") |> std/list:free(xs)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR")

std/list:new(Sample)
| list ys |> std/list:push(ys, mode: 4, label: "b")
    | ok |> std/io:print.ln("accepted-wrong") |> std/list:free(ys)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:free(ys)
| err e |> std/io:print.ln("ERR")

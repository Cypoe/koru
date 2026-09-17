// Test: the `*` marks a FALLBACK, and the catalog says what it is for. A
// default is not a term any boundary judges — push and insert enforce
// membership, and the fallback is what a boundary that SUPPLIES a value
// would pick — so the report carries it as a declared fact with its
// reader named, never as something already enforced.
//
// Expected: runs clean — `len=1`; post.sh asserts the catalog rows.
import std/proto
import std/refine
import std/list
import std/io
import std/explain

std/proto(Sample) {
    mode: i64
}

std/refine(Sample) {
    mode: i64 & *1 | 2 | 3
}

std/list:new(Sample)
| list xs |> std/list:push(xs, mode: 2)
    | ok |> std/list:len(xs): n |> std/io:print.ln("len={{ n:d }}") |> std/list:free(xs)
    | violated f |> std/io:print.ln("refused")
| err e |> std/io:print.ln("ERR")

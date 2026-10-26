// Test: the relational grammar's full surface — `==` folds to the two
// `<=` directions (its atom still spells once in the marker), `>=`
// flips onto `<=`, coefficients (`2*b`) normalize, and `& <= a + b`
// with no left side reads the field itself as the implicit LHS.
//
// Expected: Stage C prints the canonical meet (expected_comptime);
//           runtime prints `forms`.
import std/proto
import std/refine
import std/io

std/proto(L) {
    a: i64
    b: i64
    c: i64
}

std/refine(L) {
    a: i64 & a == b + c
    b: i64 & 2*b >= a
    c: i64 & <= a + b
}

std/io:print.ln("forms")

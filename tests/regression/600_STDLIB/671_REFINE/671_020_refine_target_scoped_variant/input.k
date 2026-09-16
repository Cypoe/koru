// Test: a `|variant` tag on std/refine selects a declared impl variant —
// `proc default|fpga` — and scopes the facet it lands. The universal
// facet carries unscoped blocks only; the scoped facet carries the
// materialized meet of universal + same-scope blocks (value folds
// `>=0` with `<=255`). A tag with no declared impl refuses KORU122 —
// never a silently universal facet.
//
// Expected: Stage C prints both canonical meets (expected_comptime);
//           post.sh asserts `explain` reports the scopes as separate
//           sections with their own contributor counts.
import std/proto
import std/refine
import std/io
import std/explain

std/proto(Sample) {
    value: i64
    mode: i64
}

std/refine(Sample) {
    value: i64 & >=0
    mode: i64
}

std/refine(Sample)|fpga {
    value: i64 & <=255
}

std/io:print.ln("scoped")

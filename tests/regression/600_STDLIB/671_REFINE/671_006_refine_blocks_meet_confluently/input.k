// Test: two std/refine blocks on the same type fold onto one facet —
// the meet is confluent, so `port`'s bounds from both blocks land as a
// single interval regardless of which transform fires first.
//
// Expected: Stage C prints the union meet once (expected_comptime);
//           runtime prints `met`.
import std/proto
import std/refine
import std/io

std/proto(Server) {
    port: i64
}

std/refine(Server) {
    port: i64 & >1024
}

std/refine(Server) {
    port: i64 & <=65535
}

std/io:print.ln("met")

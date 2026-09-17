// Test: an equality outside the field's own bounds refines to nothing —
// `==5 & >10` names a value the interval excludes, so the meet is empty
// and both terms are reported. Equality and bounds are separate pieces of
// the meet; neither silently wins.
//
// Expected: the compile refuses with "refines to nothing" (EXPECT).
import std/proto
import std/refine

std/proto(Server) {
    port: i64
}

std/refine(Server) {
    port: i64 & ==5 & >10
}

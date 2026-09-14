// Test: a contradictory &-meet is a loud KORU-layer refusal, never a
// last-wins override. `>20000` and `<=1000` meet to an empty interval;
// the transform names the two bounds that disagree.
//
// Expected: the compile refuses with "refines to nothing" (EXPECT).
import std/proto
import std/refine

std/proto(Server) {
    port: i64
}

std/refine(Server) {
    port: i64 & >20000 & <=1000
}

// Test: a contradictory &-meet is a loud KORU-layer refusal, never a
// last-wins override. `>20000` and `<=1000` meet to an empty interval;
// the transform names the two bounds that disagree.
//
// Expected: the compile refuses with "refines to nothing" (expected_error).
import std/refine

std/refine(Server) {
    port: int & >20000 & <=1000
}

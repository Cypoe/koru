// Test: two equalities on one field contradict — `==1` and `==2` have no
// common value, so the meet is empty and the refusal names both atoms.
// Equality cannot fold by strength the way `>N`/`<N` do; there is no
// strongest winner to keep.
//
// Expected: the compile refuses with "refines to nothing" (EXPECT).
import std/proto
import std/refine

std/proto(Server) {
    port: i64
}

std/refine(Server) {
    port: i64 & ==1 & ==2
}

// Test: the same contradiction split across two sibling blocks — block A
// says `==8080`, block B says `==9090`. The meet is one field, so the
// disagreement is empty, and it must be loud in EITHER declaration order:
// whichever block's transform fires first folds the other's text
// leniently, and a lenient contributor still carries a contradiction.
// Before the fix the second block's equality was dropped silently and the
// program compiled enforcing only the first — last-wins by declaration
// order, the exact thing `std/refine` promises never to do.
//
// Expected: the compile refuses with "refines to nothing" (EXPECT).
import std/proto
import std/refine

std/proto(Server) {
    port: i64
}

std/refine(Server) {
    port: i64 & ==8080
}

std/refine(Server) {
    port: i64 & ==9090
}

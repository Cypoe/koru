// Test: two sets sharing no value refine to nothing — sets meet by
// intersection, and an empty intersection is the same loud refusal an
// empty interval is. Never a union, never whichever block came last.
//
// Expected: the compile refuses with "refines to nothing" (EXPECT).
import std/proto
import std/refine

std/proto(Sample) {
    mode: i64
}

std/refine(Sample) {
    mode: i64 & 1 | 2
}

std/refine(Sample) {
    mode: i64 & 3 | 4
}

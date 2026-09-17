// Test: the contradiction across a SCOPE boundary — a universal `==8080`
// and an `|fpga` `==9090`. The scoped facet is the meet of universal +
// scoped blocks, so it is empty; the universal facet keeps its own
// `==8080` and is untouched. This is the fold across an already-landed
// `facet_decl`, the path a sibling block never takes.
//
// Expected: the compile refuses with "refines to nothing" (EXPECT).
import std/proto
import std/refine

std/proto(Sample) {
    value: i64
}

std/refine(Sample) {
    value: i64 & ==8080
}

std/refine(Sample)|fpga {
    value: i64 & ==9090
}

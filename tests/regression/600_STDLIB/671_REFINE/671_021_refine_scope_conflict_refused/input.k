// Test: a scoped refine meets against the universal blocks too — the
// `|fpga` facet is the meet of universal + fpga declarations, so a
// universal `>=1000` and a scoped `<=255` still meet to an empty
// interval and refuse loudly at the scoped site.
//
// Expected: the compile refuses with "refines to nothing" (EXPECT).
import std/proto
import std/refine

std/proto(Sample) {
    value: i64
}

std/refine(Sample) {
    value: i64 & >=1000
}

std/refine(Sample)|fpga {
    value: i64 & <=255
}

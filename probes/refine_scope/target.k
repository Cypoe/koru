// Probe: target-scoped std/refine. `std/refine(Sample)|fpga` selects the
// declared `proc default|fpga` impl, which stamps target="fpga" on the
// facet it lands. The universal facet carries unscoped blocks only; the
// fpga facet carries universal+fpga meets.
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

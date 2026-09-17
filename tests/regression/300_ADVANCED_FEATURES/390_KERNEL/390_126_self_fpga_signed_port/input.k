// TEST: self|fpga signedness — a met range admitting negatives emits a
// signed port. `>=-128 & <=127` is `logic signed [7:0]`, the map is
// signed arithmetic, negatives drive and check honestly: -60 * 2 is
// -120 in range; 100 * 2 is 200, which wraps to -56 on an 8-bit
// two's-complement port — the bench notes the truncation with the
// signed value, not an unsigned smear of it.
//
// Pinned shape: `k.<field> <op>= <literal>` on an int shape whose |fpga
// facet carries a negative lo bound; signed port decls, signed literals
// (`8'sd2`), and a wrapped negative result all must simulate green.

import std/proto
import std/refine
import std/kernel
import std/io

std/proto(Sample) {
    value: i64
}

std/refine(Sample)|fpga {
    value: i64 & >=-128 & <=127
}

std/kernel:shape(Sample) {
    value: i64,
}

std/kernel:init(Sample) {
    { value: -60 },
    { value: 100 },
}
| kernel k |> std/kernel:self|fpga { k.value *= 2 }
| computed c |> std/io:print.blk {
        v[0]={{ c[0].value:d }} v[1]={{ c[1].value:d }}
    }

// TEST: self|fpga width semantics — bare bounds (no clamp) size the port
// and arithmetic wraps: the port is the representation, truncation is the
// declared semantic. The generated bench computes the map signed-wide and
// prints `note: value truncated 400 -> 144 (8-bit port)` where the host
// result exceeds what the port carries — divergence is named, never silent,
// and never a fail: bounds judge the representation, they do not normalize.
//
// Pinned shape: `k.<field> <op>= <literal>` on an int shape whose |fpga
// facet carries bare `>=0 & <=255`; an init element whose map overflows
// the port still builds and sims green.

import std/proto
import std/refine
import std/kernel
import std/io

std/proto(Sample) {
    value: i64
}

std/refine(Sample)|fpga {
    value: i64 & >=0 & <=255
}

std/kernel:shape(Sample) {
    value: i64,
}

std/kernel:init(Sample) {
    { value: 200 },
}
| kernel k |> std/kernel:self|fpga { k.value *= 2 }
| computed c |> std/io:print.blk {
        v={{ c[0].value:d }}
    }

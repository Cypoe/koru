// TEST: self|fpga width semantics — a `clamp(lo,hi)` term in the |fpga
// meet claims the boundary saturates, so the emitter generates saturating
// logic (wide map, then held inside [lo,hi]) and the generated bench notes
// "saturated" where the host-wide map diverges from the port.
//
// Bounds judge, clamp normalizes — refine's own vocabulary is the ruling:
// bare `>=0 & <=255` would size the port and wrap; `clamp` asks the fabric
// to hold the range. value=200 *2 saturates to 255 on fabric while the
// host (unbounded i64) still computes 400 — the divergence is the point.
//
// Pinned shape: `k.<field> <op>= <literal>` on an int shape whose |fpga
// facet carries clamp(0,255); the sim must pass (saturation is the
// circuit's contract, the note documents the host gap).

import std/proto
import std/refine
import std/kernel
import std/io

std/proto(Sample) {
    value: i64
}

std/refine(Sample)|fpga {
    value: i64 & clamp(0,255)
}

std/kernel:shape(Sample) {
    value: i64,
}

std/kernel:init(Sample) {
    { value: 200 },
    { value: 60 },
}
| kernel k |> std/kernel:self|fpga { k.value *= 2 }
| computed c |> std/io:print.blk {
        v[0]={{ c[0].value:d }} v[1]={{ c[1].value:d }}
    }

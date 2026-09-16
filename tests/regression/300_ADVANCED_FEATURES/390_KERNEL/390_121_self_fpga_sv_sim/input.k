// TEST: self|fpga — the kernel emits a SystemVerilog stage + testbench,
// and the BUILD runs them: iverilog compiles the pair, vvp simulates the
// dataset, $fatal on a wrong beat fails the build — a broken circuit is a
// red compile, never a shipped artifact.
//
// Port widths come from the |fpga refine facet's scoped meet: value is
// i64 & >=0 & <=255 on the fpga scope, so the port is logic [7:0]; mode is
// [1:0]. The host lowering is still the ordinary Zig loop — the circuit is
// the proven artifact, not the compute path.
//
// Pinned shape: `k.<field> <op>= <literal>` on an int shape with a declared
// |fpga facet, no step, no store backing.

import std/proto
import std/refine
import std/kernel
import std/io

std/proto(Sample) {
    value: i64
    mode: i64
}

std/refine(Sample)|fpga {
    value: i64 & >=0 & <=255
    mode: i64 & >=0 & <=3
}

std/kernel:shape(Sample) {
    value: i64,
    mode: i64,
}

std/kernel:init(Sample) {
    { value: 4, mode: 1 },
    { value: 8, mode: 2 },
    { value: 16, mode: 3 },
}
| kernel k |> std/kernel:self|fpga { k.value *= 2 }
| computed c |> std/io:print.blk {
        v[0]={{ c[0].value:d }} v[1]={{ c[1].value:d }} v[2]={{ c[2].value:d }}
    }

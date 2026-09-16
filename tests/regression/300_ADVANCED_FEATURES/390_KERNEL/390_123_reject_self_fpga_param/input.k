// TEST: self|fpga takes no `[param]` — KORU122.
//
// `|mlir[gpu]` uses the bracket to select a lowering of the same
// representation. `|fpga` has exactly one lowering — the tag selects the
// artifact pipeline whole — so a parameter is a spelling error, refused by
// name rather than silently ignored.

import std/kernel
import std/io

std/kernel:shape(Sample) {
    value: i64,
}

std/kernel:init(Sample) {
    { value: 4 },
}
| kernel k |> std/kernel:self|fpga[asic] { k.value *= 2 }
| computed c |> std/io:print.blk {
        v={{ c[0].value:d }}
    }

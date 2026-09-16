// TEST: self|fpga refuses under std/kernel:step — KORU122.
//
// A fabric stage streams a static kernel dataset; a `step` chain is a state
// machine whose beat semantics (last-beat reads vs sequential-update) is the
// unruled design question the fpga-legal trellis names. Refusing is the
// honest answer — emitting a circuit that silently picks one beat semantic
// would be a lying green.

import std/kernel
import std/io

std/kernel:shape(Sample) {
    value: i64,
}

std/kernel:init(Sample) {
    { value: 4 },
}
| kernel k |> std/kernel:step(0..2)
    | step |> std/kernel:self|fpga { k.value += 1 }
| computed c |> std/io:print.blk {
        v={{ c[0].value:d }}
    }

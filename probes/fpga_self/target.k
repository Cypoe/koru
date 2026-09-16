// Probe: the fpga-legal dialect — a trellis-defined sublanguage where only
// `self` kernels are fabric-shaped today (pairwise needs a stream-vs-unroll
// scheduling ruling, step needs beat semantics, reduce needs an adder tree).
// The |fpga refine facet carries the bit-width claims the future emitter
// reads; every accepted program still runs on the Zig backend.
import std/proto
import std/refine
import std/trellis
import std/kernel
import std/io

std/trellis:define("fpga-legal")
| `.*std/kernel:pairwise.*` _ => error "std/kernel:pairwise is not fpga-legal (stream-vs-unroll scheduling unruled)"
| `.*std/kernel:step.*` _ => error "std/kernel:step is not fpga-legal (beat semantics unruled)"
| `.*std/kernel:reduce.*` _ => error "std/kernel:reduce is not fpga-legal (adder-tree emission unwritten)"
| `std/kernel:init/kernel/std/kernel:self` _ => ok
| `.*std/kernel:self` _ => error "std/kernel:self outside a kernel scope"

// The check must sit ABOVE the kernel flow in source order: transforms run
// in order, and kernel:init's own transform dissolves the chain paths the
// trellis walks — a check placed after it categorizes an empty tree.
std/trellis:check("fpga-legal")
| ok |> std/io:print.ln("fpga-legal: ok")
| error msg |> std/io:print.ln(msg)

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

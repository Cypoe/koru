// Probe: the same program requesting a step — fpga-legal's check
// categorizes it out: sequential beats re-streaming state are a state
// machine, and beat semantics (last-beat reads vs sequential-update) is
// the unruled Lars question this dialect refuses to guess.
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

std/kernel:shape(Sample) {
    value: i64,
    mode: i64,
}

std/kernel:init(Sample) {
    { value: 4, mode: 1 },
}
| kernel k |> std/kernel:step(0..2)
    | step |> std/kernel:self { k.value += 1 }
| computed c |> std/io:print.blk {
        v={{ c[0].value:d }}
    }

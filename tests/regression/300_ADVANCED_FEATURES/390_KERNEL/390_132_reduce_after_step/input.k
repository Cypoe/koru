// TEST: std/kernel — a `reduce` op chained AFTER `std/kernel:step` runs once
// over the post-step state, not once per step.
//
// The `|>` chain is sequential: a reduce chained past the step invocation
// sees the data after all steps. Measured bug: it was emitted INSIDE the
// step loop, accumulating per step (total=15 for masses [1,2] over 3
// mass+=1 steps) instead of once after (total=9).

import std/kernel
import std/io

std/kernel:shape(Pt) {
    mass: f64,
}

std/kernel:init(Pt) {
    { mass: 1.0 },
    { mass: 2.0 },
}
| kernel k |> std/kernel:step(0..3) |> std/kernel:reduce {
    total_mass[f64]
    total_mass += k.mass
}
    | step |> std/kernel:self { k.mass += 1.0 }
| reduce r |> std/io:print.blk {
        total={{ r.total_mass:f }}
    }

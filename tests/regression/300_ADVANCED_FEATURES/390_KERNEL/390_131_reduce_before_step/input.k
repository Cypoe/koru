// TEST: std/kernel — a `reduce` op chained BEFORE `std/kernel:step` runs once
// over the pre-step state, not once per step.
//
// The `|>` chain is sequential: ops before step see the initial data, ops
// under `| step |>` run per step. Measured bug: the reduce was emitted INSIDE
// the step loop, accumulating per step (total=15 for masses [1,2] over 3
// steps) instead of once before (total=3).

import std/kernel
import std/io

std/kernel:shape(Pt) {
    mass: f64,
}

std/kernel:init(Pt) {
    { mass: 1.0 },
    { mass: 2.0 },
}
| kernel k |> std/kernel:reduce {
    total_mass[f64]
    total_mass += k.mass
} |> std/kernel:step(0..3)
    | step |> std/kernel:self { k.mass += 1.0 }
| reduce r |> std/io:print.blk {
        total={{ r.total_mass:f }}
    }

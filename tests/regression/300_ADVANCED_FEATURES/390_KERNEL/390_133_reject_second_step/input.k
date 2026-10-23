// TEST: std/kernel — a second `std/kernel:step` invocation in one kernel scope
// is refused (KORU127), not silently last-wins.
//
// A kernel has exactly one step range. A chained second step would
// overwrite the first range (all step ops would run under whichever
// landed last) — a silent-wrongness shape the compiler refuses.

import std/kernel
import std/io

std/kernel:shape(Pt) {
    mass: f64,
}

std/kernel:init(Pt) {
    { mass: 1.0 },
}
| kernel k |> std/kernel:step(0..3) |> std/kernel:step(0..5)
    | step |> std/kernel:self { k.mass += 1.0 }
| computed c |> std/io:print.ln("done")

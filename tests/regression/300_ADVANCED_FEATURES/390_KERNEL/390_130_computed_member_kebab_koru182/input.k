// TEST: KORU182 on a kernel `| computed` receiver — the nbody trap shape
//
// `c[i].x-c[j]` unspaced resolves `x-c` as one member NAME — under the
// uniform `-`-is-an-identifier ruling it was never subtraction. The flow
// checker resolves the `| computed` binding to the kernel's `shape(T)`
// field set ({x, mass} here) and fires KORU182: `x-c` is no field, `x`
// is, `c` resolves. Complement of 390_129, which pins the same program
// written correctly with spaced subtraction.
//
// Note the nbody showcase's own carrier stays behind a named wall:
// `captured { ... }` args carry captured source (transform data), which
// this pass does not open — same contract as 220_055's transform-condition
// gap. The diagnostic covers every SCANNED carrier; captured-source text
// is a separate decision.

import std/kernel
import std/io

tor sink { v: f64 } -> i64
sink -> 0

std/kernel:shape(Body) {
    x: f64,
    mass: f64,
}

std/kernel:init(Body) {
    { x: 0.0, mass: 1.0 },
    { x: 1.0, mass: 2.0 },
}
| kernel k |> std/kernel:self { k.x += 1.0 }
| computed c |> sink(v: c[0].x-c[1].x): r |> std/io:print.ln(v: r)

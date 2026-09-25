// PINS: a kernel:shape declaration field list with a dropped comma —
// `y: f64\n    mass: f64` — refuses KORU170 naming the fused field when init
// consumes it, instead of emitting `y: f64 mass: f64` into the host struct
// decl and dying in backend Zig.
import std/kernel
import std/io

std/kernel:shape(Body) {
    x: f64,
    y: f64
    mass: f64,
}

std/kernel:init(Body) {
    x: 42.0,
    y: 0,
    mass: 1.5,
}

std/io:print.ln("unreachable")

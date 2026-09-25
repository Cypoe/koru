// PINS: a kernel:init dataset field list with a dropped comma —
// `x: 42.0 y: 0` — refuses KORU170 naming the fused field. init's splitters
// are bare comma splits; the one field parser (struct_literal.parseFields)
// validates the list before they run, so the fused line never reaches the
// emitted static as `.x = 42.0 y: 0`.
import std/kernel
import std/io

std/kernel:shape(Body) {
    x: f64,
    y: f64,
    mass: f64,
}

std/kernel:init(Body) {
    x: 42.0
    y: 0,
    mass: 1.5,
}

std/io:print.ln("unreachable")

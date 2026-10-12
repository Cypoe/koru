// PINS: [strict] read by the witness-check pass — an enforced program
// marked [strict] refuses every stored write the numeric check could not
// prove lossless. `0.1` is a decimal literal with no exact f32 value, so
// its mark is `f32<-literal:0.1 rounds` and the write dies at analysis
// with a per-site KORU161 naming the column, the literal, and the
// rounding.

[strict]

import std/io
import std/store
import std/witness

std/witness:enforce { }

std/store:new(bodies, capacity: 4) { x: f32, big: f64 }

std/store:insert(bodies) { x: 1.5, big: 2.25 }

std/store:query(bodies)
! query b |> std/store:stored { b.x: 0.1 }

std/io:print.ln("done")

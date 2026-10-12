// PINS: [strict] + std/witness:enforce admits exactly the stored writes
// the numeric check proves lossless — a proven f32 column read widening
// into f64, and a decimal literal with an exact f32 value. Both marks
// ride the lowered writes to the witness-check pass, which prints the
// site lines and the census instead of refusing. K3_WITNESS opts the
// Lean oracle leg in under KORU_K3=1.
//
//   b.big: b.x   — f32 proven source into an f64 column: lossless
//   b.x: 1.5     — decimal literal exactly representable in f32:
//                  lossless, carrying its text as literal:1.5
//
// The refusing twin is 690_365; the un-strict marks census is 690_364.

[strict]

import std/io
import std/store
import std/witness

std/witness:enforce { }

std/store:new(bodies, capacity: 4) { x: f32, big: f64 }

std/store:insert(bodies) { x: 1.5, big: 2.25 }

std/store:query(bodies)
! query b |> std/store:stored { b.big: b.x }

std/store:query(bodies)
! query b |> std/store:stored { b.x: 1.5 }

std/io:print.ln("done")

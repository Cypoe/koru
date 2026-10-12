// PINS: the prepared-witness channel — the numeric verdict the `stored`
// transform already computes per write site is minted as a @witness mark
// on the LOWERED write invocation (.marks — compiler-internal,
// unauthorable), and `std/witness:enforce` enumerates the marks on the
// post-transform AST.
//
//   b.big: b.x  — f32 proven source into an f64 column: lossless
//   b.x: 1.5    — a literal the checker cannot prove: deferred, not
//                 guessed safe and not refused either
//
// The verdict tag set is lossless | deferred | non-numeric | refused;
// `refused` never survives minting because the program dies at the
// refusal — 690_160 pins that half.

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

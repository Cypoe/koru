// PINS: the prepared-witness channel — the numeric verdict the `stored`
// transform already computes per write site is minted as a @witness mark
// on the LOWERED write invocation (.marks — compiler-internal,
// unauthorable), and `std/witness:enforce` enumerates the marks on the
// post-transform AST: one site line per mark in walk order, then the
// census line.
//
//   b.big: b.x        — f32 proven source into an f64 column: lossless
//   b.x: 1.5          — a decimal literal exactly representable in f32:
//                       lossless, carrying its text as literal:1.5
//   b.x: 0.1          — a decimal literal not exactly representable in
//                       f32: rounds, never guessed safe and never refused
//   b.big: 16777217   — an integer literal beyond 2^24 but inside f64's
//                       exact range: lossless, literal:16777217
//
// The verdict tag set is lossless | rounds | deferred | non-numeric |
// refused; `refused` never survives minting because the program dies at
// the refusal — 690_160 pins that half.

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

std/store:query(bodies)
! query b |> std/store:stored { b.x: 0.1 }

std/store:query(bodies)
! query b |> std/store:stored { b.big: 16777217 }

std/io:print.ln("done")

// PINS: two solver widenings behind one channel —
//
//   b.hp: b.hp - 20       — literal operand adopts its typed peer (Zig
//                           peer resolution): 20 is exact in i64, so the
//                           RHS proves i64: lossless, i64<-i64
//   b.x: b.x * 0.5        — 0.5 is exact in f32: lossless, f32<-f32
//   b.x: b.x + 0.1        — 0.1 is not exact in f32, so the literal
//                           cannot adopt: unproven, deferred
//   gauge.sel: gauge.sel + 1 — a capacity-1 store's column type resolves
//                           from the create's seed block (-1[i64]):
//                           lossless, i64<-i64
//
// Before this rung the singleton column resolved to no type at all (the
// insert decl is synthesized for plural stores only) and every
// literal-operand arithmetic write deferred.

import std/io
import std/store
import std/witness

std/witness:enforce { }

std/store:new(entities, capacity: 4) { hp: i64, x: f32 }

std/store:insert(entities) { hp: 100, x: 1.5 }

std/store:new(gauge) { sel: -1[i64] }

std/store:query(entities)
! query b |> std/store:stored { b.hp: b.hp - 20 }

std/store:query(entities)
! query b |> std/store:stored { b.x: b.x * 0.5 }

std/store:query(entities)
! query b |> std/store:stored { b.x: b.x + 0.1 }

std/store:stored { gauge.sel: gauge.sel + 1 }

std/io:print.ln("done")

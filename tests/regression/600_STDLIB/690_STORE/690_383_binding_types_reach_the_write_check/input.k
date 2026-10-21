// PINS: the binding environment reaches the stored-write check —
//
//   stats.total: h              — `h` is the watch-branch binding of column
//                                 hp (i64): scope resolution proves i64,
//                                 lossless, i64<-i64
//   b.hp: b.hp + @as(i64, 3)    — the author's @as coercion is proven
//                                 (Zig refuses a lossy @as): i64<-i64
//   stats.hits: r               — `r` binds the insert row record, not a
//                                 numeric type: stays unproven, deferred
//
// Before this rung a bound name was opaque to the solver: every `x <- name`
// write deferred no matter what the branch had bound.

import std/io
import std/store
import std/witness

std/witness:enforce { }

std/store:new(stats) { total: 0[i64], hits: 0[i64] }

std/store:new(players, capacity: 8) { hp: i64, x: f32 }

std/store:watch(players)
! hp h |> std/store:stored { stats.total: h }

std/store:insert(players) { hp: 80, x: 1.5 }

std/store:query(players)
! query b |> std/store:stored { b.hp: b.hp + @as(i64, 3) }

std/store:insert(players) { hp: 50, x: 0.5 }
| row r |> std/store:stored { stats.hits: r }

std/io:print.ln("done")

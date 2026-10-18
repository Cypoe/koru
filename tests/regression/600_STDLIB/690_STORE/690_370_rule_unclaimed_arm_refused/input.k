// PINS: the REFUSAL of an unclaimed `| done` branch arm on a
// `std/store:rule` transform site — the coordinator-side twin of
// 690_364 (query site). `rule` claims exactly `! row`; written anyway,
// the arm parses as an ordinary branch continuation, the coordinator
// replaces the site with the emitted sweep, and the arm evaporates:
// the continuation NEVER runs and no diagnostic says so. The audit in
// SPlan.unclaimedArm refuses it by name before resolution.

import std/io
import std/store

std/store:new(game, capacity: 4) { hp: i32 }

std/store:rule(game)
! row e when e.hp > 0 |> std/io:print.ln("{{ e.hp:d }}")
| done |> std/io:print.ln("never")

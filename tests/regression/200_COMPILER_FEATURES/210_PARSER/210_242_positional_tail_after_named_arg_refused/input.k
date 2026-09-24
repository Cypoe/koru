// PINS: the law holds regardless of arg order — a bare literal after a
// legal named arg still cannot pun. `capacity: 64` is fine; the trailing
// `9` is not. Measured 2026-09-24: std/ construct heads admit positional
// tails and each transform free-styles over them.
import std/store

std/store:new(game, capacity: 64, 9) { hp: i64 }

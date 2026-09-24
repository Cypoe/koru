// PINS: the same law on a free-form callee — store:new reads `capacity`
// from its own invocation args, so no declared parameter saves you. Two
// `capacity:` labels were silently resolved last-wins (measured: emitted
// [32]i64 columns). A repeated label is never meaningful — refuse.
import std/store

std/store:new(dogs, capacity: 64, capacity: 32) { hp: i64 }

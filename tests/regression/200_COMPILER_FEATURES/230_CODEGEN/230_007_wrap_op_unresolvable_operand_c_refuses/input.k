// PINS the C-lane honesty contract for wrapping ops on operands whose
// declared width the emitter cannot see. `w.wa` lowers to a store member
// read (`__koru_store_w.wa`) — a cell, not a scope binding — and `1` is a
// literal; neither resolves through the binding-type registry, so the C
// lane must REFUSE rather than guess a wrap width. Guessing i64 (the
// unadorned cell) would silently wrap at the wrong bound for a declared
// i32 column. The zig lane runs the same program — `+%` is native there
// and needs no resolution.
import std/io
import std/store

std/store:new(w) { wa: 2000000000[i32] }

pub tor bump { a: i32 } -> i32
bump -> w.wa +% 1

bump(a: 3): x |> std/io:print.ln("bump={{ x:d }}")

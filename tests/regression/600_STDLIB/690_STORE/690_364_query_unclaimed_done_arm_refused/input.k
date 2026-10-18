// PINS: the REFUSAL of an unclaimed `| done` branch arm on a
// `std/store:query` transform site. `query` is a transform — its site
// declares `! query` / `! first` / `| none` and no `done`. Written anyway,
// the arm parses as an ordinary branch continuation, the transform
// replaces the invocation node with the emitted sweep loop, and the
// dangling arm evaporates: the continuation NEVER runs and no diagnostic
// says so (measured: the row body prints, "after" never does).
//
// Silent mis-compile is worse than refusal. The pin is that the compiler
// REJECTS the unclaimed arm — the diagnostic must name 'done'. Emitting
// it as an after-loop continuation is an equally acceptable landing; this
// test then flips to MUST_RUN and the expected output gains the line.
//
// The idiom that works today: name the sweep as a tor and continue the
// caller's `|>` chain past the call — the call returns when the sweep
// finishes.

import std/io
import std/store

std/store:new(rows, capacity: 4) { v: i64 }

std/store:insert(rows) { v: 1 }
| row _ |> _
| full |> _

std/store:query(rows)
! query r |> std/io:print.ln("row {{ r.v:d }}")
| done |> std/io:print.ln("after")

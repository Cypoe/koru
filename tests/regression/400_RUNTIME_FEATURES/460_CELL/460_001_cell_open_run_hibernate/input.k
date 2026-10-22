// Test: `std/cell:open(room_state, id: ...)` — the standalone custodian path.
//
// The shape name is comptime: `open`'s transform resolves `room_state` against
// the program's `std/proto(...)` decls. `| cell c` hands the caller the `cell!`
// obligation — owned custody, settled only by `hibernate` (which wants
// `<!cell>`). `run` is a borrow-time dispatch into the session.
//
// Also pins the scoped-custody shape: hibernate lives INSIDE the `| cell` arm
// body (KORU108 — an arm's bindings end with that arm), joined after the run
// dispatch.

import std/io
import std/cell
import std/proto
import std/runtime
import std/interpreter

std/proto(room_state) {
    visits: u32
}

// `-> name` echoes the arg — proves it crossed the wire. `{{ }}` is fmt/print
// template vocabulary, not a string-literal feature, and a runtime `++`
// produce can't emit yet (520_008) — so no "hello {{ name:s }}" here.
pub tor greet { name: string } -> string
greet -> name

std/runtime:register(scope: "cell") {
    greet(5)
}

std/cell:open(room_state, id: "assistant")
| cell c |> std/cell:run(c, source: "greet(name: \"assistant\")")
  | result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("cell said: {{ j:s }}")
  | error e |> std/io:print.ln("turn failed: {{ e.kind:s }}")
  |> std/cell:hibernate(c) |> std/io:print.ln("assistant hibernated")

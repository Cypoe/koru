// Test: `std/node` — a registry-owned index of named cells over `std/bridge`.
//
// `std/node(expr)` is a transform that reads the expression's shape:
//   std/node(node)          bare name  → borrows the node   `| node f`
//   std/node(node.room-42)  member     → borrows that cell `| cell c`
//   std/node(node["id"])    subscript  → same, runtime key
//
// The caller only ever holds borrows: `create` mints `*Bridge<session!>` inside
// the node, `run` sees `*Bridge<session>`, `close` (which wants `<!session>`)
// stays node-internal via `evict`/`drain`. Member lookup requires `not-found`;
// a dormant cell is a stated decision, not a skipped arm.
//
// Also pins drain: the node's registry, index, and owned bridges are real
// allocations, and a program that doesn't drain leaks them loudly.

import std/io
import std/node
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
}

pub tor greet { name: string } -> string
greet -> "hello {{ name:s }}"

std/runtime:register(scope: "cell") {
    greet(5)
}

// Worldless node: the harness runs output binaries with cwd = repo root, so a
// world root would litter it. Per-cell world mounting is exercised in the
// probe; this test pins the grammar and the custody chain.
std/node:new(node, scope: "cell", world: "", capacity: 8)

// node borrow → spawn a cell
std/node(node)
| node f |> std/node:spawn(f, id: "room-42", cell: room_state)
  | spawned b |> std/io:print.ln("spawned room-42")
  | resident |> std/io:print.ln("resident")
  | refused |> std/io:print.ln("refused")

// member lookup → borrowed cell → cell:run dispatch
std/node(node.room-42)
| cell b |> std/cell:run(c: b, source: "greet(name: \"room-42\")")
  | result r |> std/io:print.ln("cell said: {{ r.bound:s }}")
  | error e |> std/io:print.ln("turn failed: {{ e.kind:s }}")
| not-found |> std/io:print.ln("room-42 missing")

// the borrow carries `*Cell<cell>` — the typed capture surface composes on it:
// seed from (empty) state, chain writes, commit at the `! as` leaf
std/node(node.room-42)
| cell b |> std/cell:capture(b, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 41 }
  | captured f |> std/io:print.ln("captured visits={{ f.visits:d }}")
| not-found |> std/io:print.ln("room-42 missing")

// member lookup on a cell that was never spawned
std/node(node.nope)
| cell b |> std/io:print.ln("nope found")
| not-found |> std/io:print.ln("nope missing")

// evict — the node hangs the owned bridge up
std/node(node)
| node f |> std/node:evict(f, id: "room-42")
  | evicted |> std/io:print.ln("room-42 evicted")
  | absent |> std/io:print.ln("room-42 absent")

// subscript lookup after evict — runtime key spelling
std/node(node["room-42"])
| cell b |> std/io:print.ln("room-42 back")
| not-found |> std/io:print.ln("room-42 gone")

// a second resident so drain has something to retire
std/node(node)
| node f |> std/node:spawn(f, id: "room-7", cell: room_state)
  | spawned b |> std/io:print.ln("spawned room-7")
  | resident |> std/io:print.ln("resident")
  | refused |> std/io:print.ln("refused")

// drain — close every resident cell, retire the node; the leak check counts
// every byte the registry still held.
std/node(node)
| node f |> std/node:drain(f): n |> std/io:print.ln("drained {{ n:d }} cell(s)")

// Test: `std/fleet` — a registry-owned index of named cells over `std/bridge`.
//
// `std/fleet(expr)` is a transform that reads the expression's shape:
//   std/fleet(node)          bare name  → borrows the fleet   `| fleet f`
//   std/fleet(node.room-42)  member     → borrows that cell `| cell c`
//   std/fleet(node["id"])    subscript  → same, runtime key
//
// The caller only ever holds borrows: `create` mints `*Bridge<session!>` inside
// the fleet, `run` sees `*Bridge<session>`, `close` (which wants `<!session>`)
// stays fleet-internal via `evict`/`drain`. Member lookup requires `not-found`;
// a dormant cell is a stated decision, not a skipped arm.
//
// Also pins drain: the fleet's registry, index, and owned bridges are real
// allocations, and a program that doesn't drain leaks them loudly.

import std/io
import std/fleet
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

// Worldless fleet: the harness runs output binaries with cwd = repo root, so a
// world root would litter it. Per-cell world mounting is exercised in the
// probe; this test pins the grammar and the custody chain.
std/fleet:new(node, scope: "cell", world: "", capacity: 8)

// fleet borrow → spawn a cell
std/fleet(node)
| fleet f |> std/fleet:spawn(f, id: "room-42", cell: room_state)
  | spawned b |> std/io:print.ln("spawned room-42")
  | resident |> std/io:print.ln("resident")
  | refused |> std/io:print.ln("refused")

// member lookup → borrowed cell → cell:run dispatch
std/fleet(node.room-42)
| cell b |> std/cell:run(c: b, source: "greet(name: \"room-42\")")
  | result r |> std/io:print.ln("cell said: {{ r.bound:s }}")
  | error e |> std/io:print.ln("turn failed: {{ e.kind:s }}")
| not-found |> std/io:print.ln("room-42 missing")

// the borrow carries `*Cell<cell>` — the typed capture surface composes on it:
// seed from (empty) state, chain writes, commit at the `! as` leaf
std/fleet(node.room-42)
| cell b |> std/cell:capture(b, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 41 }
  | captured f |> std/io:print.ln("captured visits={{ f.visits:d }}")
| not-found |> std/io:print.ln("room-42 missing")

// member lookup on a cell that was never spawned
std/fleet(node.nope)
| cell b |> std/io:print.ln("nope found")
| not-found |> std/io:print.ln("nope missing")

// evict — the fleet hangs the owned bridge up
std/fleet(node)
| fleet f |> std/fleet:evict(f, id: "room-42")
  | evicted |> std/io:print.ln("room-42 evicted")
  | absent |> std/io:print.ln("room-42 absent")

// subscript lookup after evict — runtime key spelling
std/fleet(node["room-42"])
| cell b |> std/io:print.ln("room-42 back")
| not-found |> std/io:print.ln("room-42 gone")

// a second resident so drain has something to retire
std/fleet(node)
| fleet f |> std/fleet:spawn(f, id: "room-7", cell: room_state)
  | spawned b |> std/io:print.ln("spawned room-7")
  | resident |> std/io:print.ln("resident")
  | refused |> std/io:print.ln("refused")

// drain — close every resident cell, retire the fleet; the leak check counts
// every byte the registry still held.
std/fleet(node)
| fleet f |> std/fleet:drain(f): n |> std/io:print.ln("drained {{ n:d }} cell(s)")

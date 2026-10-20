// Test: member lookup does not split-brain. nodea owns a dormant cell
// (spawned, captured, evicted — state on the floor, record says nodea);
// nodeb's `std/node(nodeb...)` lookup on the same id is `| held-by
// nodea`, never activated. A lookup on a never-existing id is still
// `| not-found` — and claims nothing, so the probe stays `| free`.

import std/io
import std/fleet
import std/node
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
}

std/runtime:register(scope: "cell") {
}

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_009_member_lookup_held_by_foreign/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/node:new(nodea, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_009_member_lookup_held_by_foreign/world", capacity: 8)
std/node:new(nodeb, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_009_member_lookup_held_by_foreign/world", capacity: 8)

std/node(nodea)
| node f |> std/node:retire(f, id: "room-42")
  | retired |> std/io:print.ln("slate cleared")
  | held-by o |> std/io:print.ln("slate held by {{ o:s }}")
  | absent |> std/io:print.ln("slate cleared")

std/node(nodea)
| node f |> std/node:retire(f, id: "room-99")
  | retired |> std/io:print.ln("slate cleared")
  | held-by o |> std/io:print.ln("slate held by {{ o:s }}")
  | absent |> std/io:print.ln("slate cleared")

std/node(nodea)
| node f |> std/node:spawn(f, id: "room-42", cell: room_state)
  | spawned b |> std/io:print.ln("nodea spawned room-42")
  | resident |> std/io:print.ln("resident")
  | held-by o |> std/io:print.ln("nodea refused: held by {{ o:s }}")
  | refused |> std/io:print.ln("refused")

std/node(nodea.room-42)
| cell c |> std/cell:capture(c, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 41 }
  | captured f |> std/io:print.ln("committed visits={{ f.visits:d }}")
| held-by o |> std/io:print.ln("lookup refused: held by {{ o:s }}")
| not-found |> std/io:print.ln("lost")

std/node(nodea)
| node f |> std/node:evict(f, id: "room-42")
  | evicted |> std/io:print.ln("nodea evicted — dormant, still owned")
  | absent |> std/io:print.ln("absent")

std/node(nodeb.room-42)
| cell c |> std/io:print.ln("nodeb activated room-42 — BUG")
| held-by o |> std/io:print.ln("nodeb refused: held by {{ o:s }}")
| not-found |> std/io:print.ln("not found")

std/node(nodeb.room-99)
| cell c |> std/io:print.ln("nodeb activated room-99")
| held-by o |> std/io:print.ln("nodeb refused: held by {{ o:s }}")
| not-found |> std/io:print.ln("room-99 not found")

std/fleet:owner(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_009_member_lookup_held_by_foreign/world", id: "room-99")
  | owned-by o |> std/io:print.ln("room-99 owned by {{ o:s }} — phantom claim, BUG")
  | free |> std/io:print.ln("room-99 is free — not-found claimed nothing")
  | failed e |> std/io:print.ln("probe failed {{ e:s }}")

std/node(nodea)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodea drained {{ n:d }}")
std/node(nodeb)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodeb drained {{ n:d }}")

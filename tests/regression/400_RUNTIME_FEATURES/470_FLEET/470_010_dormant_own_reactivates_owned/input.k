// Test: ownership survives hibernation. nodea spawns, captures, evicts —
// the record still says nodea — and a member lookup reactivates the same
// dormant cell under the same ownership: the fleet gate answers `held`
// for the owner itself, so resident state and durable identity agree.

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

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_010_dormant_own_reactivates_owned/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/node:new(nodea, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_010_dormant_own_reactivates_owned/world", capacity: 8)

std/node(nodea)
| node f |> std/node:retire(f, id: "room-42")
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
  | evicted |> std/io:print.ln("evicted — dormant")
  | absent |> std/io:print.ln("absent")

std/fleet:owner(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_010_dormant_own_reactivates_owned/world", id: "room-42")
  | owned-by o |> std/io:print.ln("dormant and owned by {{ o:s }}")
  | free |> std/io:print.ln("room-42 is free — ownership lost on evict, BUG")
  | failed e |> std/io:print.ln("probe failed {{ e:s }}")

std/node(nodea.room-42)
| cell c |> std/cell:capture(c, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 1 }
  | captured f |> std/io:print.ln("reactivated: visits={{ f.visits:d }}")
| held-by o |> std/io:print.ln("reactivate refused: held by {{ o:s }}")
| not-found |> std/io:print.ln("lost")

std/node(nodea)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodea drained {{ n:d }}")

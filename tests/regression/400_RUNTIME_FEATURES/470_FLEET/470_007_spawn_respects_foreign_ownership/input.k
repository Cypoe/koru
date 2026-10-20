// Test: spawn goes through the fleet boundary. Two nodes, one world:
// nodea spawns room-42 and the owner record lands with it; nodeb's spawn
// on the same id is `| held-by nodea` — spawn cannot mint a second
// custody over a foreign cell, and the arm names who does hold it.

import std/io
import std/fleet
import std/node
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
}

std/runtime:register(scope: "cell") {
}

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_007_spawn_respects_foreign_ownership/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/node:new(nodea, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_007_spawn_respects_foreign_ownership/world", capacity: 8)
std/node:new(nodeb, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_007_spawn_respects_foreign_ownership/world", capacity: 8)

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

std/node(nodeb)
| node f |> std/node:spawn(f, id: "room-42", cell: room_state)
  | spawned b |> std/io:print.ln("nodeb spawned room-42")
  | resident |> std/io:print.ln("resident")
  | held-by o |> std/io:print.ln("nodeb refused: held by {{ o:s }}")
  | refused |> std/io:print.ln("refused")

std/node(nodea)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodea drained {{ n:d }}")
std/node(nodeb)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodeb drained {{ n:d }}")

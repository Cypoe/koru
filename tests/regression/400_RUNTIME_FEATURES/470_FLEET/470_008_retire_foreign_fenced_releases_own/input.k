// Test: retire respects ownership at the durable floor. nodeb cannot
// retire a cell nodea owns — `| held-by`, the identity survives — while
// nodea's own retire both deletes the cell and releases the owner record,
// so the probe goes `| free`. Destroying what you don't own is fenced.

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

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_008_retire_foreign_fenced_releases_own/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/node:new(nodea, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_008_retire_foreign_fenced_releases_own/world", capacity: 8)
std/node:new(nodeb, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_008_retire_foreign_fenced_releases_own/world", capacity: 8)

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
| node f |> std/node:retire(f, id: "room-42")
  | retired |> std/io:print.ln("nodeb retired room-42")
  | held-by o |> std/io:print.ln("nodeb fenced: held by {{ o:s }}")
  | absent |> std/io:print.ln("absent")

std/fleet:owner(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_008_retire_foreign_fenced_releases_own/world", id: "room-42")
  | owned-by o |> std/io:print.ln("still owned by {{ o:s }}")
  | free |> std/io:print.ln("room-42 is free")
  | failed e |> std/io:print.ln("probe failed {{ e:s }}")

std/node(nodea)
| node f |> std/node:retire(f, id: "room-42")
  | retired |> std/io:print.ln("nodea retired room-42")
  | held-by o |> std/io:print.ln("nodea fenced: held by {{ o:s }}")
  | absent |> std/io:print.ln("absent")

std/fleet:owner(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_008_retire_foreign_fenced_releases_own/world", id: "room-42")
  | owned-by o |> std/io:print.ln("still owned by {{ o:s }}")
  | free |> std/io:print.ln("room-42 is free")
  | failed e |> std/io:print.ln("probe failed {{ e:s }}")

std/node(nodea)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodea drained {{ n:d }}")
std/node(nodeb)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodeb drained {{ n:d }}")

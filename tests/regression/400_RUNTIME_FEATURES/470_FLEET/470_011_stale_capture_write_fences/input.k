// Test: the epoch fence gates the write, not the turn. nodea claims
// room-42 at epoch 1 and flushes visits=41; nodeb seizes at epoch 2;
// nodea's next capture RUNS — the compute is not fenced — but the
// durable write dies at cellFlush because the record no longer names
// nodea at epoch 1. nodeb then activates the id and reads visits=41:
// the stale write never landed.

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

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_011_stale_capture_write_fences/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/node:new(nodea, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_011_stale_capture_write_fences/world", capacity: 8)
std/node:new(nodeb, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_011_stale_capture_write_fences/world", capacity: 8)

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

std/fleet:seize(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_011_stale_capture_write_fences/world", id: "room-42", node: "nodeb")
  | seized e |> std/io:print.ln("nodeb seized at epoch {{ e:d }}")
  | free |> std/io:print.ln("seize: room-42 already free")
  | contended |> std/io:print.ln("seize contended")
  | failed e |> std/io:print.ln("seize failed {{ e:s }}")

std/node(nodea.room-42)
| cell c |> std/cell:capture(c, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 1 }
  | captured f |> std/io:print.ln("stale write ran: visits={{ f.visits:d }}")
| held-by o |> std/io:print.ln("lookup refused: held by {{ o:s }}")
| not-found |> std/io:print.ln("lost")

std/node(nodeb.room-42)
| cell c |> std/cell:get(c, field: "visits")
  | value v |> std/io:print.ln("nodeb reads visits={{ v.int:d }}")
  | unknown-field e |> std/io:print.ln("no field")
  | unset u |> std/io:print.ln("unset")
| held-by o |> std/io:print.ln("nodeb refused: held by {{ o:s }}")
| not-found |> std/io:print.ln("lost")

std/node(nodea)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodea drained {{ n:d }}")
std/node(nodeb)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodeb drained {{ n:d }}")

// Process B — runs AFTER process A has exited. The record still says
// nodea: lookup is held-by, seize takes it at epoch 2, activation reads
// the durable state nodea wrote, and the new owner writes under its
// own epoch.

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

std/node:new(nodeb, scope: "cell", world: "/tmp/koru-fleet-2proc/world", capacity: 8)

std/fleet:owner(world: "/tmp/koru-fleet-2proc/world", id: "room-42")
  | owned-by o |> std/io:print.ln("record says: {{ o:s }}")
  | free |> std/io:print.ln("record free")
  | failed e |> std/io:print.ln("probe failed {{ e:s }}")

std/node(nodeb.room-42)
| cell c |> std/io:print.ln("nodeb activated room-42")
| held-by o |> std/io:print.ln("lookup refused: held by {{ o:s }}")
| not-found |> std/io:print.ln("not found")

std/fleet:seize(world: "/tmp/koru-fleet-2proc/world", id: "room-42", node: "nodeb", ttl-ms: 0)
  | seized e |> std/io:print.ln("nodeb seized at epoch {{ e:d }}")
  | free |> std/io:print.ln("already free")
  | contended |> std/io:print.ln("contended")
  | failed e |> std/io:print.ln("seize failed {{ e:s }}")

std/node(nodeb.room-42)
| cell c |> std/cell:get(c, field: "visits")
  | value v |> std/io:print.ln("nodeb reads visits={{ v.int:d }}")
  | unknown-field e |> std/io:print.ln("no field")
  | unset u |> std/io:print.ln("unset")
| held-by o |> std/io:print.ln("still held by {{ o:s }}")
| not-found |> std/io:print.ln("not found")

std/node(nodeb.room-42)
| cell c |> std/cell:capture(c, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 1 }
  | captured f |> std/io:print.ln("nodeb committed visits={{ f.visits:d }}")
| held-by o |> std/io:print.ln("held by {{ o:s }}")
| not-found |> std/io:print.ln("lost")

std/node(nodeb)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodeb exits, drained {{ n:d }}")

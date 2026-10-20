// Process A: claim room-42 on the shared world, write state, exit.
// The ownership record must outlive this process — that is the point.

import std/io
import std/node
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
}

std/runtime:register(scope: "cell") {
}

std/node:new(nodea, scope: "cell", world: "/tmp/koru-fleet-2proc/world", capacity: 8)

std/node(nodea)
| node f |> std/node:spawn(f, id: "room-42", cell: room_state)
  | spawned b |> std/io:print.ln("nodea spawned room-42")
  | resident |> std/io:print.ln("resident")
  | held-by o |> std/io:print.ln("held by {{ o:s }}")
  | refused |> std/io:print.ln("refused")

std/node(nodea.room-42)
| cell c |> std/cell:capture(c, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 41 }
  | captured f |> std/io:print.ln("nodea committed visits={{ f.visits:d }}")
| held-by o |> std/io:print.ln("held by {{ o:s }}")
| not-found |> std/io:print.ln("lost")

std/node(nodea)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodea exits, drained {{ n:d }}")

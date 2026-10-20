// Process B — runs AFTER A's lease expired (~1.4s > 900ms ttl). No
// seize, no operator: the member lookup itself takes the lapsed lease
// and activates the durable state nodea wrote, then commits under the
// new epoch.

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

std/node:new(nodeb, scope: "cell", world: "/tmp/koru-fleet-lease-2proc/world", capacity: 8, lease-ms: 900)

std/node(nodeb.room-42)
| cell c |> std/cell:get(c, field: "visits")
  | value v |> std/io:print.ln("nodeb activated lapsed lease, reads visits={{ v.int:d }}")
  | unknown-field e |> std/io:print.ln("no field")
  | unset u |> std/io:print.ln("unset")
| held-by o |> std/io:print.ln("nodeb refused: held by {{ o:s }}")
| not-found |> std/io:print.ln("nodeb: not found")

std/node(nodeb.room-42)
| cell c |> std/cell:capture(c, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 1 }
  | captured f |> std/io:print.ln("nodeb committed visits={{ f.visits:d }}")
| held-by o |> std/io:print.ln("held by {{ o:s }}")
| not-found |> std/io:print.ln("lost")

std/node(nodeb)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodeb exits, drained {{ n:d }}")

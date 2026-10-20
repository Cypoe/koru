// PROCESS A — owns the cell, sleeps while B posts, drains the mailbox on
// wake and executes each delivered turn against the resident cell.
import std/io
import std/fleet
import std/node
import std/cell
import std/proto
import std/runtime
import std/time

std/proto(room_state) {
    visits: u32
}

pub tor touch { k: u32 } -> u32
touch -> k + 1

std/runtime:register(scope: "cell") {
    touch(5)
}

std/node:new(nodea, scope: "cell", world: "WORLD", capacity: 8)

std/node(nodea)
| node f |> std/node:spawn(f, id: "room-mb", cell: room_state)
  | spawned b |> std/io:print.ln("nodea spawned room-mb")
  | resident |> std/io:print.ln("nodea: room-mb resident")
  | held-by o |> std/io:print.ln("nodea refused: held by {{ o:s }}")
  | refused |> std/io:print.ln("nodea refused")

std/node(nodea.room-mb)
| cell c |> std/cell:capture(c, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 41 }
  | captured f |> std/io:print.ln("nodea committed visits={{ f.visits:d }}")
| held-by o |> std/io:print.ln("nodea lookup refused: {{ o:s }}")
| not-found |> std/io:print.ln("nodea: room-mb lost")

// Sleep while the refused process posts to the mailbox.
std/time:sleep-ms(ms: 1500)

std/fleet:drain(world: "WORLD", id: "room-mb", node: "nodea")
! mail m |> std/io:print.ln("nodea takes mail from {{ m.from:s }}: {{ m.body:s }}")
  |> std/node(nodea.room-mb)
    | cell c |> std/cell:run(c, source: m.body)
      | result r |> std/cell:capture(c, shape: room_state)
        ! as s |> std/cell:captured { visits: s.visits + 1 }
      | error e |> std/io:print.ln("turn failed: {{ e.kind:s }}")
    | held-by o |> std/io:print.ln("nodea lost room-mb mid-drain: {{ o:s }}")
    | not-found |> std/io:print.ln("room-mb vanished")
| done n |> std/io:print.ln("nodea delivered {{ n:d }} mails")
| held-by o |> std/io:print.ln("nodea drain refused: {{ o:s }}")
| free |> std/io:print.ln("room-mb unowned")
| contended |> std/io:print.ln("drain contended")
| failed e |> std/io:print.ln("drain failed {{ e:s }}")

std/node(nodea.room-mb)
| cell c |> std/cell:get(c, field: "visits")
  | value v |> std/io:print.ln("nodea reads visits={{ v.int:d }}")
  | unset u |> std/io:print.ln("visits unset")
  | unknown-field e |> std/io:print.ln("no field")
| held-by o |> std/io:print.ln("lookup refused: {{ o:s }}")
| not-found |> std/io:print.ln("lost")

std/node(nodea)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodea exits, drained {{ n:d }}")

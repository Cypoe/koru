// PROCESS B — refused the cell, so it posts turns to the mailbox instead:
// `held-by` is a redirect, not a dead end.
import std/io
import std/fleet
import std/node

std/node:new(nodeb, scope: "cell", world: "WORLD", capacity: 8)

std/node(nodeb.room-mb)
| cell c |> std/io:print.ln("nodeb activated room-mb (BUG)")
| held-by o |> std/fleet:send(world: "WORLD", id: "room-mb", from: "nodeb", body: "touch(k: 1)")
    | posted |> std/io:print.ln("nodeb refused by {{ o:s }} — posted turn to mailbox")
    | failed e |> std/io:print.ln("send failed {{ e:s }}")
| not-found |> std/io:print.ln("nodeb: not-found")

std/fleet:send(world: "WORLD", id: "room-mb", from: "nodeb", body: "touch(k: 2)")
  | posted |> std/io:print.ln("nodeb posted a second turn")
  | failed e |> std/io:print.ln("send 2 failed {{ e:s }}")

std/node(nodeb)
| node f |> std/node:drain(f): n |> std/io:print.ln("nodeb exits, drained {{ n:d }}")

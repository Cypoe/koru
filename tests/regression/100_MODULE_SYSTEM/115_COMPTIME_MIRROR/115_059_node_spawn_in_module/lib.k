import std/io
import std/node
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
}

pub tor greet { name: string } -> string
greet -> name

std/runtime:register(scope: "cell") {
    greet(5)
}

// spawn's transform rides the head of this tor's own flow — the bare
// `std/node(node)` borrow above it is node:default at its own head.
pub tor spawn-room {}
spawn-room = std/node(node)
| node f |> std/node:spawn(f, id: "room-42", cell: room_state)
  | spawned b |> std/io:print.ln("spawned room-42")
  | resident |> std/io:print.ln("resident")
  | held-by o |> std/io:print.ln("held by {{ o:s }}")
  | refused |> std/io:print.ln("refused")

pub tor run {}

run = std/node:new(node, scope: "cell", world: "", capacity: 8)
|> spawn-room()
|> std/node(node)
| node f |> std/node:drain(f): n |> std/io:print.ln("drained {{ n:d }} cell(s)")

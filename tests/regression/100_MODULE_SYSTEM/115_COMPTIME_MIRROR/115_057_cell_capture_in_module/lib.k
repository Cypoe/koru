import std/io
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
    name: string
}

pub tor greet { name: string } -> string
greet -> name

std/runtime:register(scope: "cell") {
    greet(5)
}

pub tor run {}

run = std/cell:open(room_state, id: "room-7")
| cell c |> std/cell:capture(c, shape: room_state)
    ! as s |> std/cell:captured { visits: s.visits + 1 }
      |> std/cell:captured { name: "assistant-01" }
    | captured f |> std/io:print.ln("captured: visits={{ f.visits:d }} name={{ f.name:s }}")
  |> std/cell:hibernate(c) |> std/io:print.ln("room-7 hibernated")

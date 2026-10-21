// Test: the anonymous capture binding. `! as _` mints a compiler-internal
// record name (__koru_cellcap_<line>) when the caller wants a write-only
// capture — `std/cell:captured { f: expr }` writes need no record name.
// Witness for the __koru_cellcap_{} emit variant (variant-coverage).

import std/io
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
    awake: bool
}

pub tor greet { name: string } -> string
greet -> "hello {{ name:s }}"

std/runtime:register(scope: "cell") {
    greet(5)
}

std/cell:open(room_state, id: "room-9")
| cell c |> std/cell:capture(c, shape: room_state)
    ! as _ |> std/cell:captured { visits: 7, awake: true }
    | captured f |> std/io:print.ln("captured: visits={{ f.visits:d }} awake={{ f.awake:any }}")
  |> std/cell:hibernate(c) |> std/io:print.ln("room-9 hibernated")

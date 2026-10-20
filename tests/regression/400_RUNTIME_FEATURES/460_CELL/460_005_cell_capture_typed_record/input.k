// Test: the cell capture — a storage-agnostic transaction surface.
//
// `std/cell:capture(c, shape: room_state)` binds a live record typed from the
// proto block (`! as s` — `s.visits` compiles as u32), `std/cell:captured { f: expr }`
// blocks dissolve into field-wise assignments on the record, and the `! as`
// arm's end is the commit: every declared field writes back to the cell's
// state in one seam. `| captured f` is the after-read — the committed record.
// A second capture seeds from committed state. The shape is the
// control.capture/captured grammar aimed at a proto-typed cell, not a new
// vocabulary; the flush is the single point a materializer will one day own.

import std/io
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
    name: string
    awake: bool
}

pub tor greet { name: string } -> string
greet -> "hello {{ name:s }}"

std/runtime:register(scope: "cell") {
    greet(5)
}

std/cell:open(room_state, id: "room-7")
| cell c |> std/cell:capture(c, shape: room_state)
    ! as s |> std/io:print.ln("seeded visits={{ s.visits:d }}")
      |> std/cell:captured { visits: s.visits + 1 }
      |> std/cell:captured { name: "assistant-01" }
      |> std/cell:captured { awake: true }
    | captured f |> std/io:print.ln("c1 captured: visits={{ f.visits:d }} name={{ f.name:s }} awake={{ f.awake:any }}")
  |> std/cell:get(c, field: "visits")
    | value v |> std/io:print.ln("map sees visits = {{ v.int:d }}")
    | unknown-field e |> std/io:print.ln("no field")
    | unset u |> std/io:print.ln("unset")
  |> std/cell:capture(c, shape: room_state)
    ! as s2 |> std/cell:captured { visits: s2.visits + 10 }
    | captured f2 |> std/io:print.ln("c2 captured: visits={{ f2.visits:d }} name={{ f2.name:s }} awake={{ f2.awake:any }}")
  |> std/cell:hibernate(c) |> std/io:print.ln("room-7 hibernated")

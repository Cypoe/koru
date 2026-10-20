// Test: the durable lifecycle — `evict` hibernates (state.kv survives on the
// world floor), a member lookup re-activates the cell with state restored,
// `retire` deletes the durable record so `not-found` means never-existed.
// Residency is a cache; the directory is the truth — Orleans activate-on-
// demand against a flat-file materializer.

import std/io
import std/fleet
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
}

std/runtime:register(scope: "cell") {
}

// World root inside the test dir (the 440_040 precedent). The opening retire
// clears residue from a previous run — the test is idempotent either way.
std/fleet:new(node, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/450_FLEET/450_006_durable_evict_reactivate/world", capacity: 8)

std/fleet(node)
| fleet f |> std/fleet:retire(f, id: "room-42")
  | retired |> std/io:print.ln("slate cleared")
  | absent |> std/io:print.ln("slate cleared")

std/fleet(node)
| fleet f |> std/fleet:spawn(f, id: "room-42", cell: room_state)
  | spawned b |> std/io:print.ln("spawned room-42")
  | resident |> std/io:print.ln("resident")
  | refused |> std/io:print.ln("refused")

std/fleet(node.room-42)
| cell c |> std/cell:capture(c, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 41 }
  | captured f |> std/io:print.ln("committed visits={{ f.visits:d }}")
| not-found |> std/io:print.ln("lost")

// evict — the cell leaves memory; its state.kv stays on the floor
std/fleet(node)
| fleet f |> std/fleet:evict(f, id: "room-42")
  | evicted |> std/io:print.ln("evicted")
  | absent |> std/io:print.ln("absent")

// member lookup on a dormant cell: re-activate, state restored
std/fleet(node.room-42)
| cell c |> std/cell:get(c, field: "visits")
  | value v |> std/io:print.ln("reactivated visits={{ v.int:d }}")
  | unset u |> std/io:print.ln("state lost")
  | unknown-field e |> std/io:print.ln("no field")
| not-found |> std/io:print.ln("reactivation failed")

// spawn on a dormant id reports the identity, not a fresh mint
std/fleet(node)
| fleet f |> std/fleet:spawn(f, id: "room-42", cell: room_state)
  | spawned b |> std/io:print.ln("spawned again")
  | resident |> std/io:print.ln("resident — id taken")
  | refused |> std/io:print.ln("refused")

// retire — the durable record dies; lookup misses for real now
std/fleet(node)
| fleet f |> std/fleet:retire(f, id: "room-42")
  | retired |> std/io:print.ln("retired")
  | absent |> std/io:print.ln("absent")

std/fleet(node.room-42)
| cell c |> std/io:print.ln("LOST")
| not-found |> std/io:print.ln("retired stays gone")

std/fleet(node)
| fleet f |> std/fleet:drain(f): n |> std/io:print.ln("drained {{ n:d }} cell(s)")

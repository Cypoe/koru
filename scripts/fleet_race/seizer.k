// Seize race: N processes race takeover of the same 8 ids, each pre-seeded
// with a 'deadnode' owner record at epoch 1. seize is not exclusive-win —
// the lock dir serializes each takeover, so EVERY seizer that holds the
// lock legitimately wins at its own bumped epoch. The invariants:
//
//   seized epochs are unique AND contiguous per id  — the lock serialized
//   final record names the max-epoch seizer        — the bump committed
//   | contended is legal                            — lock collision answer
//   | free and | failed are forbidden               — the record exists
//
// world is baked in by run.sh via sed.

import std/io
import std/args
import std/fleet
import std/proto
import std/runtime

std/runtime:register(scope: "cell") {
}

std/args:get(index: 1)
| arg me
  |> std/fleet:seize(world: "@WORLD@", id: "room-s01", node: me, ttl-ms: 0)
  | seized e |> std/io:print.ln("{{ me:s }} seized room-s01 @{{ e:d }}")
  | free |> std/io:print.ln("{{ me:s }} LIED free room-s01")
  | contended |> std/io:print.ln("{{ me:s }} contended room-s01")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-s01: {{ e:s }}")
  |> std/fleet:seize(world: "@WORLD@", id: "room-s02", node: me, ttl-ms: 0)
  | seized e |> std/io:print.ln("{{ me:s }} seized room-s02 @{{ e:d }}")
  | free |> std/io:print.ln("{{ me:s }} LIED free room-s02")
  | contended |> std/io:print.ln("{{ me:s }} contended room-s02")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-s02: {{ e:s }}")
  |> std/fleet:seize(world: "@WORLD@", id: "room-s03", node: me, ttl-ms: 0)
  | seized e |> std/io:print.ln("{{ me:s }} seized room-s03 @{{ e:d }}")
  | free |> std/io:print.ln("{{ me:s }} LIED free room-s03")
  | contended |> std/io:print.ln("{{ me:s }} contended room-s03")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-s03: {{ e:s }}")
  |> std/fleet:seize(world: "@WORLD@", id: "room-s04", node: me, ttl-ms: 0)
  | seized e |> std/io:print.ln("{{ me:s }} seized room-s04 @{{ e:d }}")
  | free |> std/io:print.ln("{{ me:s }} LIED free room-s04")
  | contended |> std/io:print.ln("{{ me:s }} contended room-s04")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-s04: {{ e:s }}")
  |> std/fleet:seize(world: "@WORLD@", id: "room-s05", node: me, ttl-ms: 0)
  | seized e |> std/io:print.ln("{{ me:s }} seized room-s05 @{{ e:d }}")
  | free |> std/io:print.ln("{{ me:s }} LIED free room-s05")
  | contended |> std/io:print.ln("{{ me:s }} contended room-s05")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-s05: {{ e:s }}")
  |> std/fleet:seize(world: "@WORLD@", id: "room-s06", node: me, ttl-ms: 0)
  | seized e |> std/io:print.ln("{{ me:s }} seized room-s06 @{{ e:d }}")
  | free |> std/io:print.ln("{{ me:s }} LIED free room-s06")
  | contended |> std/io:print.ln("{{ me:s }} contended room-s06")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-s06: {{ e:s }}")
  |> std/fleet:seize(world: "@WORLD@", id: "room-s07", node: me, ttl-ms: 0)
  | seized e |> std/io:print.ln("{{ me:s }} seized room-s07 @{{ e:d }}")
  | free |> std/io:print.ln("{{ me:s }} LIED free room-s07")
  | contended |> std/io:print.ln("{{ me:s }} contended room-s07")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-s07: {{ e:s }}")
  |> std/fleet:seize(world: "@WORLD@", id: "room-s08", node: me, ttl-ms: 0)
  | seized e |> std/io:print.ln("{{ me:s }} seized room-s08 @{{ e:d }}")
  | free |> std/io:print.ln("{{ me:s }} LIED free room-s08")
  | contended |> std/io:print.ln("{{ me:s }} contended room-s08")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-s08: {{ e:s }}")
| out-of-bounds |> std/io:print.ln("usage: seizer <node-name>")

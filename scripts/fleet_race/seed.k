// Seed for the seize race: claims room-s01..s08 under the node name given
// as argv[1] (run.sh passes 'deadnode') so each record exists at epoch 1
// before the racers run. Run on a fresh world — run.sh rm -rf's it first.
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
  |> std/fleet:claim(world: "@WORLD@", id: "room-s01", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} seeded room-s01")
  | held-by o |> std/io:print.ln("seed room-s01 held by {{ o:s }}")
  | failed e |> std/io:print.ln("seed room-s01 FAILED: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-s02", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} seeded room-s02")
  | held-by o |> std/io:print.ln("seed room-s02 held by {{ o:s }}")
  | failed e |> std/io:print.ln("seed room-s02 FAILED: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-s03", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} seeded room-s03")
  | held-by o |> std/io:print.ln("seed room-s03 held by {{ o:s }}")
  | failed e |> std/io:print.ln("seed room-s03 FAILED: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-s04", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} seeded room-s04")
  | held-by o |> std/io:print.ln("seed room-s04 held by {{ o:s }}")
  | failed e |> std/io:print.ln("seed room-s04 FAILED: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-s05", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} seeded room-s05")
  | held-by o |> std/io:print.ln("seed room-s05 held by {{ o:s }}")
  | failed e |> std/io:print.ln("seed room-s05 FAILED: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-s06", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} seeded room-s06")
  | held-by o |> std/io:print.ln("seed room-s06 held by {{ o:s }}")
  | failed e |> std/io:print.ln("seed room-s06 FAILED: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-s07", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} seeded room-s07")
  | held-by o |> std/io:print.ln("seed room-s07 held by {{ o:s }}")
  | failed e |> std/io:print.ln("seed room-s07 FAILED: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-s08", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} seeded room-s08")
  | held-by o |> std/io:print.ln("seed room-s08 held by {{ o:s }}")
  | failed e |> std/io:print.ln("seed room-s08 FAILED: {{ e:s }}")
| out-of-bounds |> std/io:print.ln("usage: seed <node-name>")

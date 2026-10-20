// Multi-id claim race: each of N processes claims the same 16 cell ids
// under a node name passed as argv[1]. Per-id exactly one owner must win
// regardless of process scheduling; every loser must name that winner on
// `| held-by`. `| failed` is the arm this probe exists to keep silent —
// a loser racing the createNew→writeAll window once read a zero-byte
// record and answered `failed`; the bounded re-read in fleetAcquire
// closed it. world is baked in by run.sh via sed.

import std/io
import std/args
import std/fleet
import std/proto
import std/runtime

std/runtime:register(scope: "cell") {
}

std/args:get(index: 1)
| arg me
  |> std/fleet:claim(world: "@WORLD@", id: "room-r01", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r01 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r01 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r01: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r02", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r02 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r02 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r02: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r03", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r03 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r03 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r03: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r04", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r04 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r04 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r04: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r05", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r05 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r05 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r05: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r06", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r06 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r06 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r06: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r07", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r07 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r07 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r07: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r08", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r08 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r08 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r08: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r09", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r09 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r09 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r09: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r10", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r10 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r10 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r10: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r11", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r11 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r11 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r11: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r12", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r12 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r12 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r12: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r13", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r13 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r13 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r13: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r14", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r14 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r14 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r14: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r15", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r15 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r15 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r15: {{ e:s }}")
  |> std/fleet:claim(world: "@WORLD@", id: "room-r16", node: me)
  | claimed e |> std/io:print.ln("{{ me:s }} won room-r16 @{{ e:d }}")
  | held-by o |> std/io:print.ln("{{ me:s }} lost room-r16 to {{ o:s }}")
  | failed e |> std/io:print.ln("{{ me:s }} FAILED room-r16: {{ e:s }}")
| out-of-bounds |> std/io:print.ln("usage: racer <node-name>")

// 470_015 — cross-module tor-name collision on the inline-splice path.
// `std/fleet:drain` and `std/node:drain` share the leaf `drain`; module-
// nested decls carry unqualified paths (["drain"]), and the eligibility
// lookup (findDefaultZigProc on event_decl.path) first-matched across ALL
// modules — with node imported before fleet, node's drain body (which
// references `f.members`) was spliced into a call typed as fleet's drain
// and the emitted backend could not compile. The proc must come from the
// module_decl that declares the resolved event. A drain on an owned cell
// with an empty mailbox answers `done 0` — proof fleet's body ran.

import std/io
import std/node
import std/fleet
import std/cell
import std/proto
import std/runtime
import std/time

std/proto(counter) {
    hits: u32
}

pub tor touch { k: u32 } -> u32
touch -> k + 1

std/runtime:register(scope: "cell") {
    touch(5)
}

std/node:new(nodea, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_015_fleet_drain_not_node_drain/world", capacity: 8)

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_015_fleet_drain_not_node_drain/world")
| cleared |> std/io:print.ln("world cleared")
| failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/node(nodea)
| node f |> std/node:retire(f, id: "grain")
  | retired |> std/io:print.ln("slate cleared")
  | held-by o |> std/io:print.ln("slate held by {{ o:s }}")
  | absent |> std/io:print.ln("slate cleared")

std/node(nodea)
| node f |> std/node:spawn(f, id: "grain", cell: counter)
  | spawned _ |> std/io:print.ln("spawned")
  | resident |> std/io:print.ln("resident")
  | held-by o |> std/io:print.ln("held-by {{ o:s }}")
  | refused |> std/io:print.ln("refused")

std/time:now(): t
  |> std/fleet:drain(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_015_fleet_drain_not_node_drain/world", id: "grain", node: "nodea")
    ! mail m |> std/node(nodea.grain)
      | cell c |> std/io:print.ln("mail turn")
      | held-by o |> std/io:print.ln("lost")
      | not-found |> std/io:print.ln("gone")
    | done n |> std/io:print.ln("done {{ n:d }}")
    | held-by o |> std/io:print.ln("held-by {{ o:s }}")
    | free |> std/io:print.ln("free")
    | contended |> std/io:print.ln("contended")
    | failed e |> std/io:print.ln("failed {{ e:s }}")
  |> std/time:elapsed(start: t): _
  |> std/io:print.ln("drain done")

std/node(nodea)
| node f |> std/node:drain(f): n1 |> std/io:print.ln("drained {{ n1:d }}")

// Test: the guard's owner path and its free path. The record's holder with
// its granted epoch gets `| owner` — the write may proceed; after release
// the same guard is `| free` — nothing to fence against, nothing owned.

import std/io
import std/fleet

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_005_guard_owner_then_free/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_005_guard_owner_then_free/world", id: "room-42", node: "node-a", ttl-ms: 0)
  | claimed e |> std/io:print.ln("node-a claimed epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("a refused: held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/fleet:guard(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_005_guard_owner_then_free/world", id: "room-42", node: "node-a", epoch: 1)
  | owner |> std/io:print.ln("node-a owns: write may proceed")
  | fenced e |> std/io:print.ln("node-a fenced: record now epoch={{ e:d }}")
  | free |> std/io:print.ln("no owner record")
  | failed e |> std/io:print.ln("guard failed {{ e:s }}")

std/fleet:release(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_005_guard_owner_then_free/world", id: "room-42", node: "node-a")
  | released |> std/io:print.ln("node-a released")
  | not-owner |> std/io:print.ln("node-a refused: not the owner")
  | free |> std/io:print.ln("nothing to release")
  | failed e |> std/io:print.ln("release failed {{ e:s }}")

std/fleet:guard(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_005_guard_owner_then_free/world", id: "room-42", node: "node-a", epoch: 1)
  | owner |> std/io:print.ln("node-a owns: write may proceed")
  | fenced e |> std/io:print.ln("node-a fenced: record now epoch={{ e:d }}")
  | free |> std/io:print.ln("no owner record — nothing to fence")
  | failed e |> std/io:print.ln("guard failed {{ e:s }}")

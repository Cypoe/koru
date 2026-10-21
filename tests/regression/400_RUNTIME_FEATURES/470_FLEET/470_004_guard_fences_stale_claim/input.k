// Test: the epoch fence at the write — celld's core invariant as a runtime
// check. node-a claims at epoch 1, node-b seizes at epoch 2, and node-a's
// guard on its stale epoch is `| fenced` with the epoch now on record: the
// takeover makes every in-flight write from the old owner a refusal.

import std/io
import std/fleet

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_004_guard_fences_stale_claim/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_004_guard_fences_stale_claim/world", id: "room-42", node: "node-a", ttl-ms: 0)
  | claimed e |> std/io:print.ln("node-a claimed epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("a refused: held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/fleet:seize(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_004_guard_fences_stale_claim/world", id: "room-42", node: "node-b", ttl-ms: 0)
  | seized e |> std/io:print.ln("node-b seized epoch={{ e:d }}")
  | free |> std/io:print.ln("no owner to take from")
  | contended |> std/io:print.ln("seize contended")
  | failed e |> std/io:print.ln("seize failed {{ e:s }}")

std/fleet:guard(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_004_guard_fences_stale_claim/world", id: "room-42", node: "node-a", epoch: 1)
  | owner |> std/io:print.ln("node-a still owns")
  | fenced e |> std/io:print.ln("node-a fenced: record now epoch={{ e:d }}")
  | free |> std/io:print.ln("no owner record")
  | failed e |> std/io:print.ln("guard failed {{ e:s }}")

std/fleet:guard(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_004_guard_fences_stale_claim/world", id: "room-42", node: "node-b", epoch: 2)
  | owner |> std/io:print.ln("node-b still owns")
  | fenced e |> std/io:print.ln("node-b fenced: record now epoch={{ e:d }}")
  | free |> std/io:print.ln("no owner record")
  | failed e |> std/io:print.ln("guard failed {{ e:s }}")

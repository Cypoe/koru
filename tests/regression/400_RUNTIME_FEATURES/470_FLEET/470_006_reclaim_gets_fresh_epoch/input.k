// Test: epochs never repeat. node-a claims at epoch 1, releases; node-c's
// fresh claim gets epoch 2 because the counter survives release — and that
// is exactly what keeps node-a's stale epoch-1 token fenced: if the epoch
// counter reset with the record, a dead claim could pass as live.

import std/io
import std/fleet

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_006_reclaim_gets_fresh_epoch/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_006_reclaim_gets_fresh_epoch/world", id: "room-42", node: "node-a")
  | claimed e |> std/io:print.ln("node-a claimed epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("a refused: held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/fleet:release(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_006_reclaim_gets_fresh_epoch/world", id: "room-42", node: "node-a")
  | released |> std/io:print.ln("node-a released")
  | not-owner |> std/io:print.ln("node-a refused: not the owner")
  | free |> std/io:print.ln("nothing to release")
  | failed e |> std/io:print.ln("release failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_006_reclaim_gets_fresh_epoch/world", id: "room-42", node: "node-c")
  | claimed e |> std/io:print.ln("node-c claimed epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("c refused: held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/fleet:guard(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_006_reclaim_gets_fresh_epoch/world", id: "room-42", node: "node-a", epoch: 1)
  | owner |> std/io:print.ln("node-a stale token passed — BUG")
  | fenced e |> std/io:print.ln("node-a fenced: record now epoch={{ e:d }}")
  | free |> std/io:print.ln("no owner record")
  | failed e |> std/io:print.ln("guard failed {{ e:s }}")

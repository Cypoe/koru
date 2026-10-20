// Test: the conditional write. node-a wins the owner record for room-42 —
// `| claimed` carries the granted epoch; node-b's claim on the same id is
// refused with `| held-by` naming the holder, celld's bucket CAS answered
// from the shared world floor.

import std/io
import std/fleet

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_001_claim_and_held/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_001_claim_and_held/world", id: "room-42", node: "node-a")
  | claimed e |> std/io:print.ln("node-a claimed epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("a refused: held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_001_claim_and_held/world", id: "room-42", node: "node-b")
  | claimed e |> std/io:print.ln("node-b claimed epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("node-b refused: held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

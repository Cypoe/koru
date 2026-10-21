// Test: takeover. node-a holds room-42 at epoch 1; node-b seizes it (the
// health check that judged a dead is upstream — here it is the operator's
// decision), commits atomically at epoch 2, and the owner probe now names
// b. `seize` on a free id is `| free`, not a silent claim.

import std/io
import std/fleet

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_003_seize_bumps_epoch/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_003_seize_bumps_epoch/world", id: "room-42", node: "node-a", ttl-ms: 0)
  | claimed e |> std/io:print.ln("node-a claimed epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("a refused: held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/fleet:seize(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_003_seize_bumps_epoch/world", id: "room-99", node: "node-b", ttl-ms: 0)
  | seized e |> std/io:print.ln("node-b seized epoch={{ e:d }}")
  | free |> std/io:print.ln("room-99 has no owner to take from")
  | contended |> std/io:print.ln("seize contended")
  | failed e |> std/io:print.ln("seize failed {{ e:s }}")

std/fleet:seize(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_003_seize_bumps_epoch/world", id: "room-42", node: "node-b", ttl-ms: 0)
  | seized e |> std/io:print.ln("node-b seized epoch={{ e:d }}")
  | free |> std/io:print.ln("room-42 has no owner to take from")
  | contended |> std/io:print.ln("seize contended")
  | failed e |> std/io:print.ln("seize failed {{ e:s }}")

std/fleet:owner(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_003_seize_bumps_epoch/world", id: "room-42")
  | owned-by o |> std/io:print.ln("owned by {{ o:s }}")
  | free |> std/io:print.ln("room-42 is free")
  | failed e |> std/io:print.ln("probe failed {{ e:s }}")

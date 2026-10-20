// Test: the owner probe and graceful handoff. `owner` answers who holds an
// id (free before any claim); `release` only succeeds for the record's
// owner — a peer gets `| not-owner`, the owner clears it, and the probe
// goes back to `| free`.

import std/io
import std/fleet

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_002_owner_and_release/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/fleet:owner(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_002_owner_and_release/world", id: "room-42")
  | owned-by o |> std/io:print.ln("owned by {{ o:s }}")
  | free |> std/io:print.ln("room-42 is free")
  | failed e |> std/io:print.ln("probe failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_002_owner_and_release/world", id: "room-42", node: "node-a", ttl-ms: 0)
  | claimed e |> std/io:print.ln("node-a claimed epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("a refused: held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/fleet:owner(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_002_owner_and_release/world", id: "room-42")
  | owned-by o |> std/io:print.ln("owned by {{ o:s }}")
  | free |> std/io:print.ln("room-42 is free")
  | failed e |> std/io:print.ln("probe failed {{ e:s }}")

std/fleet:release(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_002_owner_and_release/world", id: "room-42", node: "node-b")
  | released |> std/io:print.ln("node-b released")
  | not-owner |> std/io:print.ln("node-b refused: not the owner")
  | free |> std/io:print.ln("nothing to release")
  | failed e |> std/io:print.ln("release failed {{ e:s }}")

std/fleet:release(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_002_owner_and_release/world", id: "room-42", node: "node-a")
  | released |> std/io:print.ln("node-a released")
  | not-owner |> std/io:print.ln("node-a refused: not the owner")
  | free |> std/io:print.ln("nothing to release")
  | failed e |> std/io:print.ln("release failed {{ e:s }}")

std/fleet:owner(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_002_owner_and_release/world", id: "room-42")
  | owned-by o |> std/io:print.ln("owned by {{ o:s }}")
  | free |> std/io:print.ln("room-42 is free")
  | failed e |> std/io:print.ln("probe failed {{ e:s }}")

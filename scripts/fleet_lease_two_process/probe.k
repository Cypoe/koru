// Probe — runs while A's lease is still live (~400ms in of 900ms).
// A member lookup across the process boundary must answer held-by:
// the lease says nodea still owns it, nobody took anything.

import std/io
import std/node
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
}

std/runtime:register(scope: "cell") {
}

std/node:new(probe, scope: "cell", world: "/tmp/koru-fleet-lease-2proc/world", capacity: 8, lease-ms: 900)

std/node(probe.room-42)
| cell c |> std/io:print.ln("probe activated early (BUG)")
| held-by o |> std/io:print.ln("probe refused: held by {{ o:s }}")
| not-found |> std/io:print.ln("probe: not found")

std/node(probe)
| node f |> std/node:drain(f): n |> std/io:print.ln("probe exits, drained {{ n:d }}")

// std/benchmarking:lap — laps fire 1..n in order, once each per pass. A pass
// that marks lap 2 first is a misplaced instrument and must die loudly, not
// report a phase. Pins the trap and its message.
import std/io
import std/benchmarking

std/benchmarking:climb(warmup: 0, frames: 1, reps: 1)
! pass |> std/benchmarking:lap(k: 2)
| done d |> std/io:print.ln("unreachable {{ d.laps:d }}")

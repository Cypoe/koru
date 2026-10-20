// std/benchmarking:climb — warmup + frames passes, `reps` times; lap(k)
// splits a pass into phases and lap.ms(k) reads each phase's lowest median,
// k = laps+1 being the tail after the last lap.
// Pins: the body fires (warmup + frames) * reps times, the done payload
// carries laps/frames/reps, and every phase's lowest median is in
// [0, frame] — a phase sample never exceeds the pass that contains it.
import std/store
import std/io
import std/benchmarking

std/store:new(world) { n: 0[i64], acc: 0[i64] }

std/benchmarking:climb(warmup: 2, frames: 5, reps: 3)
! pass
    |> std/store:stored { world.n: world.n + 1 }
    |> std/benchmarking:lap(k: 1)
    |> for(0..1000)
        ! each i |> std/store:stored { world.acc: world.acc + @as(i64, @intCast(i)) }
    |> std/benchmarking:lap(k: 2)
| done d |> std/benchmarking:lap.ms(k: 1): a1 |> std/benchmarking:lap.ms(k: 2): a2 |> std/benchmarking:lap.ms(k: 3): a3
    |> std/io:print.ln("passes {{ world.n:d }}")
    |> std/io:print.ln("laps {{ d.laps:d }} frames {{ d.frames:d }} reps {{ d.reps:d }}")
    |> if (a1 >= 0.0 and a2 >= 0.0 and a3 >= 0.0 and a1 <= d.ms and a2 <= d.ms and a3 <= d.ms)
        | then |> std/io:print.ln("phases bounded")

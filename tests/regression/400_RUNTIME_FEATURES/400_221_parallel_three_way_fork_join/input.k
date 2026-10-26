// [parallel] on three sibling binds — 3-way fork/join through the pool.
// tak(32,16,8) = 9 (Takeuchi oracle).
import std/io

pub tor tak { x: i64, y: i64, z: i64 } -> i64

tak = if(x > y)
| then |> [parallel]tak(x: x - 1, y, z): t1 |> [parallel]tak(x: y - 1, y: z, z: x): t2 |> [parallel]tak(x: z - 1, y: x, z: y): t3 |> tak(x: t1, y: t2, z: t3): v -> v
| else -> z

tak(x: 32, y: 16, z: 8): r |> std/io:print.ln("{{ r:d }}")

import std/io

pub tor chain { x: i64 }
! step i64 -> i64
| done i64

chain = step(x): a |> step(a): b |> step(b): c |> step(c): d |> step(d): e |> step(e): f |> step(f): g |> step(g): h => done h

chain(x: 0)
! step v -> v + 1
| done r |> std/io:print.ln("{{ r:d }}")

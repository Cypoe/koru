import std/io

pub tor beat {}
! tick
| done i64

pub tor pulse {}
! tick
| done i64

pulse = tick() => done 0

beat()
! tick |> _
| done r |> std/io:print.ln("done {{ r:d }}")

pulse()
! tick |> _
| done r |> std/io:print.ln("pulse {{ r:d }}")

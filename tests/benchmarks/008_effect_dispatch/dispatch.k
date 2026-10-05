import std/io

pub tor beat {}
! tick
| done i64

beat()
! tick |> _
| done r |> std/io:print.ln("done {{ r:d }}")

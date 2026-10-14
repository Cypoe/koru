// TEST: std/panic — the owned-death verdict. Inside a producing flow, a
// grafted arm that ends in std/panic:die closes the path honestly: the arm
// decided, and death is the verdict — distinct from forwarding (`=>`, the
// next frame decides) and from absence (the site's default crash). `die` is
// declared `-> noreturn` so the backend's return analysis sees the path end.

import std/io
import std/panic

pub tor risky { code: i64 }
| ok i64
| ?!bad i64

pub tor worker {}
| done
| ?!failed i64

risky = if(code < 0)
| then => bad code
| else => ok code

worker = risky(code: -1)
| ok _ => done

std/panic:catch(risky)
! bad v |> std/panic:die(msg: "worker cannot absorb bad")

worker()
| done |> std/io:print.ln("done")
| failed f |> std/io:print.ln("failed {{ f:d }}")

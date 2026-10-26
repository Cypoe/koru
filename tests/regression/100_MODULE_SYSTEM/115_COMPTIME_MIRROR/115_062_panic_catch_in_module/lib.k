import std/io
import std/panic

pub tor risky { code: i64 }
| ok i64
| ?!bad i64

risky = if(code < 0)
| then => bad code
| else => ok code

pub tor run {}

run = std/panic:catch(risky)
! bad v |> std/io:print.ln("caught {{ v:d }}")

risky(code: -1)
| ok v |> std/io:print.ln("ok {{ v:d }}")

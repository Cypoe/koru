// TEST: std/panic — the verdict discipline. A `?!` is the callee's terminal
// product; the grafted arm is the tail of the abandoned path, and inside a
// producing flow that path owes the caller an outcome. An absorb-arm with a
// bare end would trade a loud crash for a dead path — the fault surfacing
// only as a backend "implicitly returns" error about a function the author
// never wrote. catch refuses at the DECL, koru-level: the site owes a
// verdict (`=>`, `->`, or std/panic:die).

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
! bad v |> std/io:print.ln("caught {{ v:d }}")

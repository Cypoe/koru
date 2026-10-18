// TEST: std/panic — the escalate verdict. Inside a producing flow, the
// grafted arm produces `=> failed v`: the panic is NOT resolved, it is
// relocated — worker's dispatch on `risky`'s `?!bad` re-offers the failure
// as worker's own declared `?!failed`, and the caller's arm answers it.
// "Sensible to fail" made literal: the arm decided the panic wasn't theirs
// and said so in kind.

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
! bad v |> => failed v

worker()
| done |> std/io:print.ln("done")
| failed f |> std/io:print.ln("failed {{ f:d }}")

// TEST: std/panic — a `catch` decl grafts an answer onto a call site that
// left a `?!` panic branch unhandled.
//
// `?!` is the optional-to-handle branch kind: a caller that writes `| bad v |>`
// answers it; a caller that doesn't gets a synthesized @panic at the site.
// std/panic:catch moves sites from the second column to the first AT COMPTIME:
// the parens pattern selects which call sites (tap's `source -> dest` glob
// grammar, dest names the panic branch), and the `!` arms inside the decl are
// the answers — effect-branch shaped because a pillow of answers is never
// exhaustive: what it doesn't cover stays fatal.
//
// Here `risky(code: -1)` writes only `| ok`; `?!bad` is grafted from the
// catch decl, so the malformed call prints "caught -1" and the run continues.

import std/io
import std/panic

pub tor risky { code: i64 }
| ok i64
| ?!bad i64

risky = if(code < 0)
| then => bad code
| else => ok code

std/panic:catch(risky)
! bad v |> std/io:print.ln("caught {{ v:d }}")

risky(code: -1)
| ok v |> std/io:print.ln("ok {{ v:d }}")

risky(code: 3)
| ok v |> std/io:print.ln("ok {{ v:d }}")

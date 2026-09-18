// `args:` — retry arguments derived from the failure payload.
//
// `| boom f |> supervised { restart: 3, args: { n: f + 4 } }` evaluates
// each mapped expr against the arm's payload binding — at the site (the
// failure that triggered supervision) and again inside the generated
// loop against each fresh failure. This is the 320_151 hand-written
// climbing retry (`more { n: f + 4 }`) spelled as policy.
//
// Pinned: sup(-10) retries at -6, -2, 2 -> "got 2"; sup(-20) spends the
// budget at -16, -12, -8 and forwards the last boom upward ("gave up -8")
// in kind (`?!boom` stays a panic).
import std/io
import std/supervisor

pub tor worker { n: i64 }
| ok i64
| ?!boom i64

worker = std/io:print.ln("try {{ n:d }}")
|> if (n < 0)
| then => boom n
| else => ok n

pub tor sup { n: i64 }
| ok i64
| ?!boom i64

sup = worker(n)
| ok v => ok v
| boom f |> std/supervisor:supervised { restart: 3, args: { n: f + 4 } }

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

sup(n: -20)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

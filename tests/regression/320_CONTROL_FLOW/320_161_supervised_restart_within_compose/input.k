// `{ restart: N, within: N unit }` — the block shorthand composes with
// the spacing declaration: `restart: 3` generates the bounded retry loop,
// `within: 1 s` throttles it. The first re-entry is always allowed; the
// second lands inside the one-second window, is declined, and the last
// failure proceeds upward in kind — two "try" lines total.
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
| boom f |> std/supervisor:supervised { restart: 3, within: 1 s }

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

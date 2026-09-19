// `{ within: N unit }` — a policy DECLARATION field in the supervised
// block (the data slot — rules live in the arm children). `within` is the
// wall-clock min-spacing throttle: the generated unit stamps the
// nanosecond timestamp of each re-entry and declines a retry that would
// fire inside the window — keep-alive fails, and the outcome proceeds
// upward in kind like any unmet bound.
//
// Pinned: `within: 1 s` + `t < 5` shows exactly two "try" lines — the
// first re-entry is always allowed (`__last == 0` marks the site's own
// failure), the second lands inside the one-second window and is
// declined. `1 s` is the deterministic spacing: no plausible retry
// cadence outruns a second.
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
| boom f |> std/supervisor:supervised { within: 1 s }
    | retry t when t < 5

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

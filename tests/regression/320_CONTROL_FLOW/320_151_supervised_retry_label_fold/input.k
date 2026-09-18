// Pins the supervision restart shape in pure Koru — what
// `| boom f |> supervised { restart: 3 }` will elaborate to, written
// out by hand so the semantics are pinned before the transform exists.
//
// `attempt` is the policy-bearing drive step: it claims the child's
// `?!boom`, and while budget remains produces `more` (the `#retry`
// loop arm) with restart args derived from the crash payload
// (`n: f + 4`). Budget exhausted, it lets the LAST boom proceed
// upward in its own kind — absorb-and-defer, never transform.
// `#retry` folds the drive loop: state lives in the step's args as
// loop vars, `more` re-enters, terminal arms produce upward. The
// emitted code is a `while (result == .more)` loop — no runtime
// supervision machinery.
//
// restart: 3 means three retries after the initial call. sup(-10)
// attempts -10, -6, -2, 2 — the fourth call succeeds ("got 2").
// sup(-20) attempts -20, -16, -12, -8 — exhausted, the last boom
// proceeds upward ("gave up -8").
import std/io

pub tor worker { n: i64 }
| ok i64
| ?!boom i64

worker = if(n < 0)
| then => boom n
| else => ok n

tor attempt { n: i64, left: i64 }
| ok i64
| more { n: i64, left: i64 }
| boom i64

attempt = worker(n)
| ok v => ok v
| boom f when left > 0 => more { n: f + 4, left: left - 1 }
| boom f => boom f

pub tor sup { n: i64 }
| ok i64
| ?!boom i64

sup = #retry attempt(n, left: 3)
| more s |> @retry(s.n, s.left)
| ok v => ok v
| boom f => boom f

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

sup(n: -20)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

// param_init.k with the retry budget guard tightened `left > 0` ->
// `left > 1`: identical transition map, one fewer real iterate. This is
// the when-mutant hole the roadmap named — the same F with a different
// stop condition used to gate EQUAL because the guard was silently
// dropped and only the unbounded trajectory was compared. With the
// `when` modeled as the guard, the bounded lengths differ (2 vs 3)
// and the gate must say NOT-EQUAL.
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
| boom _ when left > 1 => more { n: n + 4, left: left - 1 }
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

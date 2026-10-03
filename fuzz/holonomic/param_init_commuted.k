// Pins a hole in when-guard arm-group emission: sibling arms on the
// same branch share ONE payload-capture decision, taken from the FIRST
// arm's binding. `| boom _ when left > 0` discards the payload, so the
// group emits `.boom =>` with no `|f|` capture — but the unguarded
// fallback `| boom f => boom f` still references `f`, and Zig refuses
// the emit: `error: use of undeclared identifier 'f'`.
//
// The shape is the supervision retry policy: a guarded arm absorbs the
// crash while budget remains and the fallback lets the last failure
// proceed upward — the fallback is where the payload matters.
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
| boom _ when left > 0 => more { n: 4 + n, left: -1 + left }
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

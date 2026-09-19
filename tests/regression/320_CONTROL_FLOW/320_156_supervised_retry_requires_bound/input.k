// Refusal pin: a `| retry` rule whose `when` doesn't bound on the attempt
// counter is not a keep-alive condition — it cannot guarantee the loop
// ends. The policy must carry its own escape.
//
//   | boom f |> std/supervisor:supervised
//       | retry when f < 9000 |> worker(n: f + 1)
//
// has a `when`, but the guard is on the failure payload alone — if every
// failure stays under 9000 the loop never terminates. The transform must
// refuse with KORU161: at least one `| retry` arm must bind the counter
// and bound on it (`| retry t when t < N`).
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
| boom f |> std/supervisor:supervised
    | retry when f < 9000 |> worker(n: f + 1)

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

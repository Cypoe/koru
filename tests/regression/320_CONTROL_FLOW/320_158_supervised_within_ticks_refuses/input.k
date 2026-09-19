// `{ within: N ticks }` pins the tick-unit refusal: `within` is a real
// declaration, but a tick clock has no supplier in call scope — tick
// clocks come from an enclosing signal model. The diagnostic teaches the
// wall-clock units that ARE honored today (ms|us|ns|s).
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
| boom f |> std/supervisor:supervised { within: 10 ticks }
    | retry t when t < 3

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

// A `| [within: N unit]` arm is a declaration borrowing an outcome-dispatch
// slot — an arm with no continuation reads as "on this outcome, swallow
// it," and `within: N ms` is not an outcome the child produces. Policy
// declarations are data and live in the supervised block; the refusal
// teaches the real spelling.
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
    | [within: 10 ms]
    | retry t when t < 3

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

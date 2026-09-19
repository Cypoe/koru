// Arm-policy vocabulary pin: explicit `|>` re-entry, ordered rules, and
// `| exhausted` terminal produces.
//
//   | boom f |> std/supervisor:supervised
//       | retry t when t < 3 |> worker(n: f + 4)
//       | exhausted when f == -10 => boom 0
//       | exhausted => boom f
//
// The site's children are an ordered rule list evaluated on EVERY failure
// (the site's own arrives as `__fail`): a matched `| retry` spends the
// counter and re-enters through its own `|>` call — here the climbing
// `worker(n: f + 4)`, the arm-form spelling of 320_154's `args:` block.
// `| exhausted [when c] => produce` is the terminal decision; its produce
// speaks the CHILD's branch vocabulary, so `=> boom 0` can rewrite the
// payload while `=> boom f` spells the plain forward-in-kind. An
// unconditional `| exhausted` must be last; omitting it gives the same
// forward as the default.
//
// Pinned: sup(-10) climbs -10 -> -6 -> -2 -> 2 ("got 2"); sup(-20) spends
// the counter at -8 and forwards `?!boom` in kind ("gave up -8"); sup(-22)
// reaches the counter bound carrying -10, where the conditional exhausted
// rule fires first and produces `boom 0` ("gave up 0").
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
    | retry t when t < 3 |> worker(n: f + 4)
    | exhausted when f == -10 => boom 0
    | exhausted => boom f

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

sup(n: -20)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

sup(n: -22)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

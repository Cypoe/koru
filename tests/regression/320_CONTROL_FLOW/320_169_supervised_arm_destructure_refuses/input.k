// A destructure on the supervised arm (`| boom { f } |> supervised …`) is a
// binder the fold never reads: the failure payload reaches policy and args
// expressions through the site's NAME binding (`| boom f |>`), so the
// destructured names — and any annotation on them — drop silently. The
// consumer refuses the surface it does not implement.
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
| boom { [row]f } |> std/supervisor:supervised { restart: 3, args: { n: f + 4 } }

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

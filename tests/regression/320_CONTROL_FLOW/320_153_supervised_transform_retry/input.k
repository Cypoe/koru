// First `std/supervisor:supervised` arm-policy end-to-end pin — the
// transform-driven twin of 320_151's hand-written supervision loop.
//
//   | boom f |> std/supervisor:supervised
//       | retry t when t < 3
//
// declares that the producing call is supervised: the site's children ARE
// the policy. `| retry t when t < N` binds `t` to the count of retries
// already spent — `t < 3` grants exactly three re-entries, the same bound
// the datablock spelling `{ restart: 3 }` gives. The transform generates
// an `__sup_attempt_L<line>` unit (child's input + `__fail` + branch
// vocabulary) whose |zig proc evaluates the policy rules on EVERY failure
// — including the site's own, passed in as `__fail` — and rewrites the arm
// into a call to it with the site's sibling arms cloned underneath.
//
// Semantics pinned: `t < 3` = three re-entries after the site's call
// (worker prints once per invocation — sup(-10) shows exactly four
// "try -10" lines); exhaustion forwards the LAST outcome upward in its
// own kind (`?!boom` stays a panic, caught at the top); the counter is a
// literal inside the generated proc, never a signature field.
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
    | retry t when t < 3

sup(n: 5)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

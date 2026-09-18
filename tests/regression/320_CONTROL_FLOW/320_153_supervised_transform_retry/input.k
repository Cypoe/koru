// First `std/supervisor:supervised { restart: N }` end-to-end pin —
// the transform-driven twin of 320_151's hand-written supervision loop.
//
// `| boom f |> supervised { restart: 3 }` declares that the producing
// call is supervised: the transform generates an `__sup_attempt_L<line>`
// unit (child's input + branch vocabulary) whose |zig proc is a bounded
// `while (true)` loop, and rewrites the arm into a call to it with the
// site's sibling arms cloned underneath — a retried `ok` flows through
// the same arm set as a first-call `ok`.
//
// Semantics pinned: restart: 3 = three retries after the initial call
// (worker prints once per invocation — sup(-10) shows exactly four
// "try -10" lines); exhaustion forwards the LAST outcome upward in its
// own kind (`?!boom` stays a panic, caught at the top); the budget is a
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
| boom f |> std/supervisor:supervised { restart: 3 }

sup(n: 5)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")

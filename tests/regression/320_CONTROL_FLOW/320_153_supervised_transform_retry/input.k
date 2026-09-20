// First `std/supervisor:supervised` arm-policy end-to-end pin — the
// transform-driven twin of 320_151's hand-written supervision loop.
//
//   | boom f |> std/supervisor:supervised
//       | retry t when t < 3
//
// declares that the producing call is supervised: the site's children ARE
// the policy. `| retry t when t < N` binds `t` to the count of retries
// already spent — `t < 3` grants exactly three re-entries, the same bound
// the datablock spelling `{ restart: 3 }` gives. The transform elaborates
// to the language's own `#`/`@` fold: a generated `__sup_step_L<line>`
// tor (child's inputs + the `t` counter field) whose `__more` branch
// carries the next attempt's inputs; the site reroutes its producing
// call to `#label __sup_step(args, t: 0)` and gains a
// `| __more s |> @label(s.…)` re-entry arm.
//
// Semantics pinned: `t < 3` = three re-entries after the site's call
// (worker prints once per invocation — sup(-10) shows exactly four
// "try -10" lines); exhaustion forwards the LAST outcome upward in its
// own kind (`?!boom` stays a panic, caught at the top); the counter rides
// as a step input named after the retry arm's own binding — `t` resolves
// verbatim in `when` clauses, never threaded.
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

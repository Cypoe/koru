// PINS: the REFUSAL of an unclaimed `| done` branch arm on a
// `capture` transform site — the control-flow twin of
// 690_364/690_370/340_016. `capture` claims exactly `! as` and
// `| captured`; its declared branch contract is DOCS ONLY at a
// transform site — the shape checker runs after transforms and only
// ever sees the replacement. Written anyway, the arm parses, the
// replacement is built from `as`/`captured` alone, and the arm
// evaporates: it NEVER runs and no diagnostic says so.
// ast_functional.unclaimedContinuation refuses it by name.

import std/io

capture { n: 0[i64] }
! as acc |> captured { n: acc.n + 1 }
| captured r |> std/io:print.ln("n={{ r.n:d }}")
| done |> std/io:print.ln("never")

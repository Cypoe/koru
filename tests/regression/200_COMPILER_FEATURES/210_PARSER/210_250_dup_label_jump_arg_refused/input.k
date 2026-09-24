// PINS: a label jump binds each name once. `@L(l.limit, limit: 2)` binds
// `limit` twice — PARSE009's call-site rule, which checkBareArgPunning only
// applied to Invocations. The jump compiled and RAN: the second `limit` was
// silently dropped (measured 2026-09-24 — the loop ran on the first value
// forever). Same law as 210_244, on the jump surface.
import std/io

tor tick { limit: i64, passes: i64 }
| live { limit: i64, passes: i64 }
| expired i64

tor run { limit: i64 } -> i64

tick => live { limit, passes }

run = #L tick(limit, passes: 0)
| live l |> @L(l.limit, limit: 2)
| expired e -> e

run(limit: 3): r |> std/io:print.ln("{{ r:d }}")

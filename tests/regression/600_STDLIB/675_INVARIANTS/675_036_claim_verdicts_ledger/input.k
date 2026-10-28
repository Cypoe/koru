// Under `std/witness:enforce` the claims pass commits its verdicts as
// structured `[claim-check]` lines plus a trailing `[claim-census]` — the
// corpus the Lean ledger checker (verify/claims/ClaimsCheck.lean)
// re-decides. A `CLAIMS_CHECK` marker arms the gate leg; the lines are
// pinned here as the committed record.

import std/io
import std/spec
import std/witness

tor tick { i: i64, limit: i64 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

tick = if(i < limit)
| then => live { i, limit }
| else => done i

std/witness:enforce { }

std/spec:claim(atom: terminates, on: tick) { "rank": "limit - i" }

run = #L tick(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")

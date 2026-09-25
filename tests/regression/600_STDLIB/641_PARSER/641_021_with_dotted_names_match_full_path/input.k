// PINS: `[with]` resolution must match the invocation's FULL path, not its
// last segment. app/alpha owns `say.hi`, app/beta owns `log.hi` — as written
// the names share nothing. restamp keys on the last segment (`hi`), so a bare
// `say.hi` reads as owned by BOTH vocabularies — KORU140 on a name that is
// not ambiguous. It must resolve to app/alpha's `say.hi` alone.
import std/io
import app/alpha
import app/beta

[with]app/alpha:say.hi(msg: "seed"): s |> [with]app/beta:log.hi(msg: s): t |> say.hi(msg: t): u |> std/io:print.ln("resolved={{ u:s }}")

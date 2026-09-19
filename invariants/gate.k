// gate — judge one staged-diff state against one declared rule via
// koru/odds. This is the Jev execution strategy for `git-gate`-tagged
// invariants that carry no `check:` field — the judgment class of rule
// a deterministic checker cannot reach.
//
//   argv[1]  the question — the invariant's `rule` prose, written to be
//            diff-judged
//   argv[2]  the state text — the staged diff
//
// Prints exactly one line for the runner to parse:
//   VIOLATION p=<f> | CLEAN p=<f> | UNJUDGED <why>
//
// UNJUDGED is the loud form of "the gate could not judge" — no key, no
// fuel, no args. It is never a silent pass.

import koru/odds
import std/args
import std/io

std/args:get(index: 1)
| arg q |> std/args:get(index: 2)
    | arg s |> koru/odds:judge(budget: 3): j |> koru/odds:feels(j, text: s, question: q)
        | yes p |> std/io:print.ln("VIOLATION p={{ p:f }}")
        | no p |> std/io:print.ln("CLEAN p={{ p:f }}")
        | exhausted |> std/io:print.ln("UNJUDGED fuel exhausted")
        | err e |> std/io:print.ln("UNJUDGED {{ e.msg:s }}")
    | out-of-bounds |> std/io:print.ln("UNJUDGED missing state arg")
| out-of-bounds |> std/io:print.ln("UNJUDGED missing question arg")

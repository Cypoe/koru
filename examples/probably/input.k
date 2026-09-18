// probably.k — Probably's inbox department, rewritten as Koru flows.
//
// What Probably needs four keywords for — `feels`, `match`, `chaos`,
// `otherwise maybe` — Koru already has: a branch set IS an answer
// space, a payload IS a probability, `when` IS a confidence gate,
// and sampling mode IS a phantom state on the judge.
//
// Three mails walk all three routes: a bug urgent enough to earn the
// polish loop, a feature request rerouted through a <chaotic> judge,
// and an other that goes straight to archive. Each gets its own
// judge — issued, borrowed, retired inside one subflow — `retire` is
// never spelled: the emitter splices the sole void disposer itself.

import std/io
import app/jev

// The inbox.
tor mail-bug {} -> string
tor mail-feature {} -> string
tor mail-other {} -> string

mail-bug -> "mail number 11 please fix the export button"
mail-feature -> "can we get a new icon theme"
mail-other -> "your invoice for march is attached"

// The department: one judge, eight judgments of fuel.
//
// triage is Jev's `match` — the answer space is the branch set, the
// payload its winner's probability. The urgency check is Jev's `noul`:
// a `when` clause on the payload is the confidence gate Probably
// spells `with confidence 80%`, and the un-guarded `yes`/`no` arms
// are its `otherwise maybe`.
tor route { m: string }
route = app/jev:judge(budget: 8): j |> app/jev:triage(j, text: m)
| bug p |> std/io:print.ln("route: bug     p={{ p:f }}") |> app/jev:feels(j, text: m, question: "genuinely urgent")
    | yes q when q >= 0.8 |> std/io:print.ln("drop everything        p={{ q:f }}") |> app/jev:polish(j, draft: m)
        | polished d |> std/io:print.ln("polished: {{ d:s }}")
        | exhausted |> std/io:print.ln("judge spent mid-polish")
    | no q when q >= 0.8  |> std/io:print.ln("it can wait            p={{ q:f }}")
    | yes q               |> std/io:print.ln("uncertain - follow up  p={{ q:f }}")
    | no q                |> std/io:print.ln("uncertain - follow up  p={{ q:f }}")
    | exhausted           |> std/io:print.ln("judge exhausted at urgency check")
| feature p |> std/io:print.ln("route: feature p={{ p:f }}") |> app/jev:chaos(j): cj |> app/jev:ctriage(j: cj, text: m)
    | bug q     |> std/io:print.ln("chaos reroute: bug     p={{ q:f }}") |> app/jev:settle(j: cj)
    | feature q |> std/io:print.ln("chaos reroute: feature p={{ q:f }}") |> app/jev:settle(j: cj)
    | other q   |> std/io:print.ln("chaos reroute: other   p={{ q:f }}") |> app/jev:settle(j: cj)
    | exhausted |> std/io:print.ln("judge exhausted in chaos") |> app/jev:settle(j: cj)
| other p   |> std/io:print.ln("route: other   p={{ p:f }}")
| exhausted |> std/io:print.ln("judge exhausted at triage")

mail-bug(): m |> route(m)
mail-feature(): m |> route(m)
mail-other(): m |> route(m)

// Pins: an unhandled-branch outcome names its binding. Every dispatch
// binds its result under the session's next rN — arm match or not — so
// a branch the reply forgot to arm still hands the model a durable name
// for the minted value. Without the name, a minted handle was held but
// unreachable: seeded hex can neither be predicted nor echoed back.
//
// t1: pick fires `stocked`, nobody arms it → unhandled-branch with
//     bound: r1 — custody stays reachable.
// t2: release(r: r1) — the named binding resolves to the live handle
//     and discharges it; nothing is stranded.
// t3: pick fires `empty` — a payload-less branch still gets a name.

import std/io
import std/bridge
import std/runtime
import reslib/res

std/runtime:register(scope: "res") {
    reslib.res:mint -> mint(1)
    reslib.res:pick -> pick(1)
    reslib.res:grab -> grab(1)
    reslib.res:release -> release(1)
}

tor step { br: *std/bridge:Bridge<session>, source: string<*>, tag: string }
step = std/bridge:run(br, source)
| result r |> std/io:print.ln("{{ tag:s }}: result bound {{ r.bound:s }} (holds {{ r.handles:d }})")
| unhandled-branch u |> std/io:print.ln("{{ tag:s }}: unhandled {{ u.branch:s }} bound {{ u.bound:s }}")
| partial p |> std/io:print.ln("{{ tag:s }}: partial {{ p.ran:d }}/{{ p.total:d }}")
| defined d |> std/io:print.ln("{{ tag:s }} FAIL defined {{ d:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | dispatch-error e |> std/io:print.ln("{{ tag:s }} FAIL dispatch {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("{{ tag:s }} FAIL denied {{ ev:s }}")
    | parse-error p |> std/io:print.ln("{{ tag:s }} FAIL parse {{ p.message:s }}")
    | validation-error v |> std/io:print.ln("{{ tag:s }} FAIL invalid {{ v:s }}")
    | shape-error sh |> std/io:print.ln("{{ tag:s }} FAIL shape {{ sh.message:s }}")
    | exhausted _ |> std/io:print.ln("{{ tag:s }} FAIL exhausted")
    | scope-not-found s2 |> std/io:print.ln("{{ tag:s }} FAIL noscope {{ s2:s }}")
| residue _ |> std/io:print.ln("{{ tag:s }} FAIL residue outcome")

[with]std/bridge:create(id: "u", scope: "res"): br
|> step(br, source: "pick(n: 1)", tag: "t1")
|> step(br, source: "release(r: r1)", tag: "t2")
|> step(br, source: "pick(n: 0)", tag: "t3")
|> std/bridge:close(br)

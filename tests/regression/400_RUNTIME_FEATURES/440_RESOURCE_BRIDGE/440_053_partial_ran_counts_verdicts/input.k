// Pins: `partial`'s `ran` counts steps that reached a verdict —
// attempted minus wire refusals. Before the fix it was `.ran =
// steps.total` unconditionally, printing "3/3 ran" beside refusals.
//
// Turn 1: a mint, an event-denied call, a release — three items
// attempted, one refused → ran 2/3, wire_failures 1.
//
// Turn 2: mint, release, then `abandon` — the fourth item was never
// attempted. ran 3/4 with wire_failures 0: the truncated tail counts in
// `total` but in neither other number. (Nothing may be held at close —
// the hang-up sweep prints handle text, which is seeded hex.)
//
// `p.report` is never printed — it embeds minted handle text, which is
// seeded hex and unpinnable. The counters are the contract here.

import std/io
import std/bridge
import std/runtime
import reslib/res

std/runtime:register(scope: "res") {
    reslib.res:mint -> mint(1)
    reslib.res:grab -> grab(1)
    reslib.res:release -> release(1)
}

tor quiet { br: *std/bridge:Bridge<session>, source: string<*>, tag: string }
quiet = std/bridge:run(br, source)
| partial p |> std/io:print.ln("{{ tag:s }}: ran {{ p.ran:d }}/{{ p.total:d }}, wire_failures {{ p.wire_failures:d }}, holds {{ p.handles:d }}")
| result _ |> std/io:print.ln("{{ tag:s }} FAIL unexpected result")
| unhandled-branch u |> std/io:print.ln("{{ tag:s }} FAIL unhandled {{ u.branch:s }}")
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

[with]std/bridge:create(id: "c", scope: "res", introspection: true): br
|> quiet(br, source: "mint() | ok h |>\nbogus-verb()\nrelease(r: r1)", tag: "t1")
// rN mints monotonically: t1's release result itself took r2, so the
// t2 mint is r3.
|> quiet(br, source: "mint() | ok h |>\nrelease(r: r3)\nabandon(reason: \"enough\")\nmint()", tag: "t2")
|> std/bridge:close(br)

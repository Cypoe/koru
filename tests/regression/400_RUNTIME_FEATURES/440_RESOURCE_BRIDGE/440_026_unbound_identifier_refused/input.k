// Pins: a bare identifier in arg position is a REFERENCE, and an
// unbound one is refused by name — never the identifier's own text
// smuggled to the verb. Bindings live per item along an arm path:
// `| ok h |>` puts `h` in scope inside that arm's subtree only — not
// in a second item, not in a sibling arm.
//
// Two surfaces, one law. A top-level wire item's bare value is refused
// by the wire parser itself ("no bare values" — item heads admit only
// quoted literals); an arm body's bare identifier parses (arm bodies
// are Koru fragments) and the flow's validation judges it: bound on
// this arm path it resolves, unbound it is `validation-error` naming
// the name.
//
// The wire's own lesson — "Never invent one, never predict one: bind
// it" — only teaches if inventing one is refused. An unbound `h`
// dispatching as the literal string "h" fails as `HandleNotHeld`, which
// blames the handle instead of the missing binding.
//
// (kopium bridge-mirror 2026-09-12-arm-composition — item 2's
// `append(handle: h)` dispatched literal "h" → HandleNotHeld.)
import std/io
import std/bridge
import std/runtime

tor probe { path: string }
| found string
| absent string
proc probe|zig {
    if (@import("std").mem.eql(u8, path, "hit")) {
        return .{ .found = "hit" };
    }
    return .{ .absent = "miss" };
}

tor echo { text: string }
proc echo|zig {
    @import("std").debug.print("echo: {s}\n", .{text});
}

std/runtime:register(scope: "binds") {
    probe(1)
    echo(1)
}

// Turn 1 (control): `t` is bound by the arm that carries it — the
// reference resolves and the body runs.
tor turn1 { br: *std/bridge:Bridge }
turn1 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found t |> echo(text: t)")
| result r |> std/io:print.ln("t1 result")
| validation-error v |> std/io:print.ln("FAIL t1 invalid {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t1 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t1 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t1 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t1 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t1 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t1 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t1 exhausted")
| partial p |> std/io:print.ln("FAIL t1 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t1 noscope {{ s2:s }}")

// Turn 2: item 1 binds `h`; item 2 names it. Bindings do not cross
// items — and the wire parser refuses the bare value outright, so the
// step dies as parse-error inside a `partial` outcome, item 1 intact.
tor turn2 { br: *std/bridge:Bridge }
turn2 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found h |> echo(text: \"one\")\necho(text: h)")
| result r |> std/io:print.ln("FAIL t2 result")
| validation-error v |> std/io:print.ln("FAIL t2 invalid {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t2 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t2 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t2 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t2 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t2 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t2 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t2 exhausted")
| partial p |> std/io:print.ln("t2 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t2 noscope {{ s2:s }}")

// Turn 3: a bare value on a top-level item — the wire parser's own
// refusal, before validation or dispatch ever see it.
tor turn3 { br: *std/bridge:Bridge }
turn3 = std/bridge:run(br, source: "echo(text: nope)")
| result r |> std/io:print.ln("FAIL t3 result")
| validation-error v |> std/io:print.ln("t3 refused {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t3 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("t3 refused-parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t3 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t3 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t3 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t3 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t3 exhausted")
| partial p |> std/io:print.ln("FAIL t3 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t3 noscope {{ s2:s }}")

// Turn 4: `t` is bound under `found` only — naming it under `absent`
// is unbound on that path, whatever probe would have returned.
tor turn4 { br: *std/bridge:Bridge }
turn4 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found t |> echo(text: \"f\")\n| absent a |> echo(text: t)")
| result r |> std/io:print.ln("FAIL t4 result")
| validation-error v |> std/io:print.ln("t4 refused {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t4 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t4 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t4 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t4 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t4 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t4 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t4 exhausted")
| partial p |> std/io:print.ln("FAIL t4 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t4 noscope {{ s2:s }}")

// Turn 5: a dotted reference's base is the same question — `h.msg`
// with no `h` in scope names `h`, not `<unbound:h>`.
tor turn5 { br: *std/bridge:Bridge }
turn5 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found t |> echo(text: h.msg)")
| result r |> std/io:print.ln("FAIL t5 result")
| validation-error v |> std/io:print.ln("t5 refused {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t5 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t5 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t5 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t5 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t5 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t5 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t5 exhausted")
| partial p |> std/io:print.ln("FAIL t5 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t5 noscope {{ s2:s }}")

[with]std/bridge:create(id: "b1", scope: "binds"): br
|> turn1(br)
|> turn2(br)
|> turn3(br)
|> turn4(br)
|> turn5(br)

// Pins: a second unguarded arm for a branch an earlier sibling already
// answers is UNREACHABLE — arm selection is first-match (interpreter's
// `select` part), so the later arm is dead text that reports itself as
// `result`. Interpreted flows refuse it as `validation-error`, the same
// judgment compiled flows get from SHAPE002 (branch_checker's
// firstDuplicateSibling): one unguarded terminal handler per branch per
// level. `when` narrows rather than duplicates, and an arm that follows
// a STEP is indented under that step's line — flat `|` lines are
// siblings of the head call.
//
// The shape this guards against is the model's natural chain spelling —
// `open | ok h |> append(handle: h) | ok h2 |> close(handle: h2)` reads
// as a chain but parses as two `ok` arms on `open`; the second never
// fires, `close` never dispatches, and the pool keeps the handle.
// (kopium discharged-handle probe, 2026-09-17.)
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

// Turn 1: the flat chain — a second unguarded `found` arm on `probe`
// can never fire. Refused by name, with the nesting spelling taught.
tor turn1 { br: *std/bridge:Bridge }
turn1 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found h |> echo(text: \"one\")\n| found u |> echo(text: \"two\")")
| result r |> std/io:print.ln("FAIL t1 result")
| validation-error v |> std/io:print.ln("t1 refused {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t1 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t1 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t1 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t1 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t1 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t1 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t1 exhausted")
| partial p |> std/io:print.ln("FAIL t1 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t1 noscope {{ s2:s }}")

// Turn 2: same shape on ONE line — inline arms are siblings too.
tor turn2 { br: *std/bridge:Bridge }
turn2 = std/bridge:run(br, source: "probe(path: \"hit\") | found h |> echo(text: \"one\") | found u |> echo(text: \"two\")")
| result r |> std/io:print.ln("FAIL t2 result")
| validation-error v |> std/io:print.ln("t2 refused {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t2 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t2 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t2 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t2 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t2 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t2 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t2 exhausted")
| partial p |> std/io:print.ln("FAIL t2 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t2 noscope {{ s2:s }}")

// Turn 3 (control): a guarded `found` arm narrows — the unguarded
// fallback stays reachable and fires when the guard fails.
tor turn3 { br: *std/bridge:Bridge }
turn3 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found t when t == \"nope\" |> echo(text: \"guarded-t3\")\n| found u |> echo(text: \"fallback-t3\")")
| result r |> std/io:print.ln("t3 result")
| validation-error v |> std/io:print.ln("FAIL t3 invalid {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t3 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t3 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t3 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t3 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t3 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t3 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t3 exhausted")
| partial p |> std/io:print.ln("FAIL t3 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t3 noscope {{ s2:s }}")

// Turn 4 (control): the spelling the model meant — the second arm
// indented under the step it follows attaches to `echo`, not `probe`.
tor turn4 { br: *std/bridge:Bridge }
turn4 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found h |> echo(text: \"first\")\n    | ok |> echo(text: \"second\")")
| result r |> std/io:print.ln("t4 result")
| validation-error v |> std/io:print.ln("FAIL t4 invalid {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t4 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t4 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t4 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t4 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t4 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t4 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t4 exhausted")
| partial p |> std/io:print.ln("FAIL t4 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t4 noscope {{ s2:s }}")

// Turn 5 (control): distinct branch names as siblings — the legal use
// of the flat shape the defect abused.
tor turn5 { br: *std/bridge:Bridge }
turn5 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found a |> echo(text: \"on-found\")\n| absent b |> echo(text: \"on-absent\")")
| result r |> std/io:print.ln("t5 result")
| validation-error v |> std/io:print.ln("FAIL t5 invalid {{ v:s }}")
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

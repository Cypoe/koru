// Pins: an unknown field on a known verb is `validation-error` at
// dispatch — the contract `runtime.parsewire.kz`'s header declares. The
// provided field names are judged against the verb's declared input
// vocabulary (the register's `get_event_input_<scope>` table), on every
// invocation the flow reaches: the head call, a mid-turn step, and a
// nested arm-body call. A field the signature never declared is refused
// by name; the verb never runs.
//
// Ordering: a name that is not a scope verb at all is `event-denied`,
// not a field complaint — vocabulary membership is judged before field
// membership. A runtime-defined flow's params are its own surface and
// are not judged against the scope manifest.
//
// (kopium bridge-mirror 2026-09-12-field-membership — `bogus` was
// silently ignored on every turn shape.)
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

std/runtime:register(scope: "fields") {
    probe(1)
    echo(1)
}

// Turn 1 (control): declared fields only — the verb runs.
tor turn1 { br: *std/bridge:Bridge }
turn1 = std/bridge:run(br, source: "echo(text: \"ok\")")
| result r |> std/io:print.ln("t1 result")
| validation-error v |> std/io:print.ln("FAIL t1 invalid {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t1 denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL t1 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t1 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t1 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t1 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t1 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t1 exhausted")
| partial p |> std/io:print.ln("FAIL t1 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t1 noscope {{ s2:s }}")

// Turn 2: `bogus` is not on echo's signature — refused by name.
tor turn2 { br: *std/bridge:Bridge }
turn2 = std/bridge:run(br, source: "echo(text: \"x\", bogus: \"3\")")
| result r |> std/io:print.ln("FAIL t2 result")
| validation-error v |> std/io:print.ln("t2 refused {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t2 denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL t2 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t2 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t2 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t2 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t2 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t2 exhausted")
| partial p |> std/io:print.ln("FAIL t2 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t2 noscope {{ s2:s }}")

// Turn 3: same refusal mid-turn — the bad step reports, the good step
// already ran.
tor turn3 { br: *std/bridge:Bridge }
turn3 = std/bridge:run(br, source: "echo(text: \"a\")\necho(text: \"b\", stray: \"z\")")
| result r |> std/io:print.ln("FAIL t3 result")
| validation-error v |> std/io:print.ln("FAIL t3 invalid {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t3 denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL t3 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t3 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t3 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t3 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t3 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t3 exhausted")
| partial p |> std/io:print.ln("t3 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t3 noscope {{ s2:s }}")

// Turn 4: a foreign field on a NESTED arm-body invocation is the same
// refusal — the arm never runs.
tor turn4 { br: *std/bridge:Bridge }
turn4 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found t |> echo(text: \"inner\", foreign: \"1\")")
| result r |> std/io:print.ln("FAIL t4 result")
| validation-error v |> std/io:print.ln("t4 refused {{ v:s }}")
| event-denied ev |> std/io:print.ln("FAIL t4 denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL t4 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t4 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t4 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t4 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t4 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t4 exhausted")
| partial p |> std/io:print.ln("FAIL t4 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t4 noscope {{ s2:s }}")

// Turn 5 (ordering): a name outside the vocabulary is event-denied, not
// a field complaint.
tor turn5 { br: *std/bridge:Bridge }
turn5 = std/bridge:run(br, source: "notaverb(bogus: \"1\")")
| result r |> std/io:print.ln("FAIL t5 result")
| validation-error v |> std/io:print.ln("FAIL t5 invalid {{ v:s }}")
| event-denied ev |> std/io:print.ln("t5 denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL t5 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t5 unhandled {{ ub.branch:s }}")
| shape-error sh |> std/io:print.ln("FAIL t5 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t5 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t5 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t5 exhausted")
| partial p |> std/io:print.ln("FAIL t5 partial {{ p.report:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t5 noscope {{ s2:s }}")

[with]std/bridge:create(id: "b1", scope: "fields"): br
|> turn1(br)
|> turn2(br)
|> turn3(br)
|> turn4(br)
|> turn5(br)

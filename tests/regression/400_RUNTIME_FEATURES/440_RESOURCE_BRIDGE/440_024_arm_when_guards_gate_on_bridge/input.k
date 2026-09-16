// Pins: a `when` guard on a wire arm is EVALUATED against the arm's own
// binding — same-branch arms try in source order, first truthy guard
// wins, an unguarded arm is the else. A guard that fails skips the arm;
// it never fires ungated.
//
// The wire parses `| ok t when <expr> |>` full-fidelity into
// cont.condition — so the interpreter must judge it. Ignoring it makes
// the wire wider than the semantics it feeds: a model can emit a guard
// that executes unconditionally and nothing refuses. Compiled emission
// lowers the same shape to an if/else-if/else chain; this test pins the
// interpreter to the same order.
//
// (kopium bridge-mirror 2026-09-13-arm-when-guards — `| ok t when false`
// FIRED on the bridge.)
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

std/runtime:register(scope: "guards") {
    probe(1)
    echo(1)
}

// Turn 1: guard sees the arm binding — `t == "hit"` is true, so the
// guarded arm fires and the unguarded same-branch arm does not.
tor turn1 { br: *std/bridge:Bridge }
turn1 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found t when t == \"hit\" |> echo(text: \"guarded-hit\")\n| found u |> echo(text: \"unguarded-t1\")")
| result r |> std/io:print.ln("t1 result")
| unhandled-branch ub |> std/io:print.ln("FAIL t1 unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL t1 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t1 parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL t1 invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL t1 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t1 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t1 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t1 exhausted")
| partial p |> std/io:print.ln("FAIL t1 partial")
| scope-not-found s2 |> std/io:print.ln("FAIL t1 noscope {{ s2:s }}")

// Turn 2: guard false — the guarded arm is SKIPPED and the unguarded
// same-branch arm fires. Before the fix the guarded arm fired anyway.
tor turn2 { br: *std/bridge:Bridge }
turn2 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found t when t == \"nope\" |> echo(text: \"guarded-wrong\")\n| found u |> echo(text: \"unguarded-t2\")")
| result r |> std/io:print.ln("t2 result")
| unhandled-branch ub |> std/io:print.ln("FAIL t2 unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL t2 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t2 parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL t2 invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL t2 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t2 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t2 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t2 exhausted")
| partial p |> std/io:print.ln("FAIL t2 partial")
| scope-not-found s2 |> std/io:print.ln("FAIL t2 noscope {{ s2:s }}")

// Turn 3: every guard false and no unguarded same-branch arm — nothing
// fires; the outcome is unhandled, exactly as the compiled if/else chain
// with no else leaves the dispatch untouched.
tor turn3 { br: *std/bridge:Bridge }
turn3 = std/bridge:run(br, source: "probe(path: \"hit\")\n| found t when false |> echo(text: \"never-t3\")\n| absent a |> echo(text: \"absent-t3\")")
| result r |> std/io:print.ln("FAIL t3 result")
| unhandled-branch ub |> std/io:print.ln("t3 unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL t3 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL t3 parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL t3 invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL t3 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t3 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t3 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t3 exhausted")
| partial p |> std/io:print.ln("FAIL t3 partial")
| scope-not-found s2 |> std/io:print.ln("FAIL t3 noscope {{ s2:s }}")

[with]std/bridge:create(id: "b1", scope: "guards"): br
|> turn1(br)
|> turn2(br)
|> turn3(br)

// Pins: a destructure arm inside an interpreted flow — `| missing { v }` —
// is refused at the flow's own parse, because the interpreter's eval binds
// only `| <branch> name`. Before the refusal the `{` tokenized as a literal
// binding and the field names (with any `[row]`-style annotation) dropped
// silently — a binder that bound nothing. Turn 1 is the control: a plain
// `| <branch> name` arm binds and runs.
import std/io
import std/bridge
import std/runtime

tor risky { }
| ok string
| missing string
proc risky|zig {
    return .{ .missing = "gone" };
}

tor echo { text: string }
proc echo|zig {
    @import("std").debug.print("echo: {s}\n", .{text});
}

std/runtime:register(scope: "api") {
    risky(1)
    echo(1)
}

// Turn 1 (control): the name-binding arm runs.
tor turn1 { br: *std/bridge:Bridge }
turn1 = std/bridge:run(br, source: "risky()\n| missing v |> echo(text: v)")
| result r |> std/io:print.ln("t1 result")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL t1 parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL t1 invalid {{ v:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t1 unhandled {{ ub.branch:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t1 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t1 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t1 exhausted")
| partial p |> std/io:print.ln("FAIL t1 partial {{ p.report:s }}")
| shape-error sh |> std/io:print.ln("FAIL t1 shape {{ sh.message:s }}")
| event-denied ev |> std/io:print.ln("FAIL t1 denied {{ ev:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t1 noscope {{ s2:s }}")

// Turn 2: a destructure arm refuses at the flow's own parse — annotated
// fields included — instead of silently binding a literal `{`.
tor turn2 { br: *std/bridge:Bridge }
turn2 = std/bridge:run(br, source: "risky()\n| missing { [row]v } |> echo(text: v)")
| result r |> std/io:print.ln("FAIL t2 result")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("t2 refused {{ p.message:s }}")
| validation-error v |> std/io:print.ln("t2 refused-invalid {{ v:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL t2 unhandled {{ ub.branch:s }}")
| dispatch-error e |> std/io:print.ln("FAIL t2 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL t2 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL t2 exhausted")
| partial p |> std/io:print.ln("FAIL t2 partial {{ p.report:s }}")
| shape-error sh |> std/io:print.ln("FAIL t2 shape {{ sh.message:s }}")
| event-denied ev |> std/io:print.ln("FAIL t2 denied {{ ev:s }}")
| scope-not-found s2 |> std/io:print.ln("FAIL t2 noscope {{ s2:s }}")

[with]std/bridge:create(id: "d", scope: "api"): br
|> turn1(br)
|> turn2(br)

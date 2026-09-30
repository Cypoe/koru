// TEST: a chain's middle is a reported, durable result — not just an arm
// binding that dies at turn end. `probe() | ok h |> echo(...)` must mint
// an `r{N}` for probe's value (trace shows `bound: r1 as h`), render every
// dispatched link in the turn's report, and leave `r1` addressable on the
// NEXT turn — `echo(text: r1)` re-emits probe's payload. Single-link turns
// keep the bare `result:` line: the trace exists for what `result:` cannot
// say, and duplicating one call's outcome is noise, not teaching.
import std/io
import std/bridge
import std/runtime

tor probe {} -> string
proc probe|zig {
    const std = @import("std");
    var buf: [64]u8 = undefined;
    return std.fmt.bufPrint(&buf, "payload-{d}", .{9}) catch unreachable;
}

tor echo { text: string }
proc echo|zig {
    _ = @import("std").posix.write(1, text) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

std/runtime:register(scope: "api") {
    probe(1)
    echo(1)
}

tor turn { br: *std/bridge:Bridge, src: string }
turn = std/bridge:run(br, source: src)
| result r |> std/io:print.ln("{{ r.trace:s }}RESULT bound={{ r.bound:s }}")
| partial p |> std/io:print.ln("{{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
| residue r |> std/io:print.ln("FAIL residue {{ r:s }}")
| parse-error p |> std/io:print.ln("FAIL parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("{{ e.trace:s }}FAIL dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL exhausted")
| scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")

[with]std/bridge:create(id: "mc", scope: "api"): br
|> turn(br, src: "probe() | ok h |> echo(text: \"done\")")
|> turn(br, src: "echo(text: r1)")
|> turn(br, src: "probe() | ok h |> bogus(text: h)")
|> turn(br, src: "echo(text: \"alive\")")
|> turn(br, src: "echo(text: r4)")

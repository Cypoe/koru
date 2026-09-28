// Pins: `std/bridge:run` dispatches bare typed literals end-to-end, and a
// bound scalar crosses an arm boundary into the next call's typed param.
// `add(a: 5, b: 3)` on {a: i64, b: i64} reaches the proc as real ints;
// `| ok s |>` binds the i64 result; `echo-num(n: s)` receives 8. The wire
// gate is the only layer that ever refused the literals — the dispatcher's
// buildInput parses wire text into declared types all along.
import std/io
import std/bridge
import std/runtime

tor add { a: i64, b: i64 } -> i64
proc add|zig {
    return a + b;
}

tor echo-num { n: i64 }
proc echo-num|zig {
    const std = @import("std");
    var buf: [64]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "n={d}\n", .{n}) catch unreachable;
    _ = std.posix.write(1, s) catch {};
}

std/runtime:register(scope: "api") {
    add(1)
    echo-num(1)
}

tor turn { br: *std/bridge:Bridge }
turn = std/bridge:run(br, source: "add(a: 5, b: 3) | ok s |> echo-num(n: s)")
| result _ |> std/io:print.ln("RESULT")
| partial p |> std/io:print.ln("FAIL partial {{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL exhausted")
| scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")

[with]std/bridge:create(id: "ta", scope: "api"): br
|> turn(br)

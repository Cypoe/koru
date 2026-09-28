// Pins: a bound scalar payload survives the arm hop. `produce`'s |zig proc
// formats its return into a STACK buffer and hands back a slice — dispatcher
// results are only borrowed memory until the interpreter owns them.
// `| ok v |>` binds it; `echo(text: v)` must print the payload, not the dead
// stack bytes. Borrowed-at-dispatch is garbage-at-use.
import std/io
import std/bridge
import std/runtime

tor produce {} -> string
proc produce|zig {
    const std = @import("std");
    var buf: [64]u8 = undefined;
    return std.fmt.bufPrint(&buf, "payload-{d}", .{7}) catch unreachable;
}

tor echo { text: string }
proc echo|zig {
    _ = @import("std").posix.write(1, text) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

std/runtime:register(scope: "api") {
    produce(1)
    echo(1)
}

tor turn { br: *std/bridge:Bridge }
turn = std/bridge:run(br, source: "produce() | ok v |> echo(text: v)")
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

[with]std/bridge:create(id: "bs", scope: "api"): br
|> turn(br)

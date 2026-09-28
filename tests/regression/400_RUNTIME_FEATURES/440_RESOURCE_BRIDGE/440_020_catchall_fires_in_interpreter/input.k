// Pins: a `|?` catch-all arm FIRES in the interpreter — it binds the
// outcome and runs when no named arm matched, exactly as it does on the
// compiled surface (210_017, 355_009-011).
//
// Before this pin the arm parsed (flow_parser sets is_catchall) and never
// matched: eval's arm loop compared cont.branch against the fired branch
// name, so a catch-all fell through to unhandled-branch — an arm that
// lied by existing. (kopium bridge-mirror row: 2026-09-12-branch-arms)
import std/io
import std/bridge
import std/runtime

tor risky { }
| ok string
| missing string
proc risky|zig {
    return .{ .missing = "gone" };
}

tor fine { } -> string
proc fine|zig {
    return "yes";
}

tor echo { text: string }
proc echo|zig {
    _ = @import("std").posix.write(1, text) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

std/runtime:register(scope: "api") {
    risky(1)
    fine(1)
    echo(1)
}

// Turn 1: `missing` fires, no named arm matches, the catch-all runs.
tor catchall-fires { br: *std/bridge:Bridge }
catchall-fires = std/bridge:run(br, source: "risky()\n| ok v |> echo(text: v)\n|? b |> echo(text: \"caught\")")
| result r |> std/io:print.ln("turn1 result")
| unhandled-branch ub |> std/io:print.ln("FAIL turn1 unhandled {{ ub.branch:s }} — the catch-all did not fire")
| event-denied ev |> std/io:print.ln("FAIL turn1 denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL turn1 parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL turn1 invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL turn1 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL turn1 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL turn1 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL turn1 exhausted")
| partial p |> std/io:print.ln("FAIL turn1 partial")
| scope-not-found s2 |> std/io:print.ln("FAIL turn1 noscope {{ s2:s }}")

// Turn 2: a named arm still wins over the catch-all — the catch-all is a
// fallback, not an override.
tor named-wins { br: *std/bridge:Bridge }
named-wins = std/bridge:run(br, source: "fine()\n| ok v |> echo(text: \"named-ok\")\n|? b |> echo(text: \"caught\")")
| result r |> std/io:print.ln("turn2 result")
| unhandled-branch ub |> std/io:print.ln("FAIL turn2 unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL turn2 denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL turn2 parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL turn2 invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL turn2 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL turn2 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL turn2 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL turn2 exhausted")
| partial p |> std/io:print.ln("FAIL turn2 partial")
| scope-not-found s2 |> std/io:print.ln("FAIL turn2 noscope {{ s2:s }}")

[with]std/bridge:create(id: "ca", scope: "api"): br
|> catchall-fires(br)
|> named-wins(br)

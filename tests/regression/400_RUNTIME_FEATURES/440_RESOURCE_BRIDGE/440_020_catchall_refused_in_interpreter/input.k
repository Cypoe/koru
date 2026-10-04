// Pins: a `|?` arm in interpreted source refuses the same way compiled
// source does — the turn answers `parse-error`, the dispatch never runs.
// There is no catch-all spelling on either surface; interpreted text is
// the least-trusted writer in the system and cannot smuggle a residual
// case past the boundary compiled code already enforces.
// (kopium bridge-mirror row: 2026-09-12-branch-arms)
import std/io
import std/bridge
import std/runtime

tor risky { }
| ok string
| missing string
proc risky|zig {
    return .{ .missing = "gone" };
}

std/runtime:register(scope: "api") {
    risky(1)
}

// Turn 1: `|?` in the source text refuses at parse — same PARSE003 the
// compiled surface gives, surfaced as the turn's parse-error outcome.
tor catchall-refused { br: *std/bridge:Bridge }
catchall-refused = std/bridge:run(br, source: "risky()\n| ok v |> _\n|? b |> _")
| result r |> std/io:print.ln("FAIL turn1 ran")
| parse-error p |> std/io:print.ln("turn1 parse-error — the spelling refuses")
| unhandled-branch ub |> std/io:print.ln("FAIL turn1 unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL turn1 denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| validation-error v |> std/io:print.ln("FAIL turn1 invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL turn1 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL turn1 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL turn1 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL turn1 exhausted")
| partial p |> std/io:print.ln("FAIL turn1 partial")
| scope-not-found s2 |> std/io:print.ln("FAIL turn1 noscope {{ s2:s }}")

// Turn 2: control — named arms over the same dispatch still run.
tor named-runs { br: *std/bridge:Bridge }
named-runs = std/bridge:run(br, source: "risky()\n| ok v |> _\n| missing m |> _")
| result r |> std/io:print.ln("turn2 named-arms result")
| parse-error p |> std/io:print.ln("FAIL turn2 parse {{ p.message:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL turn2 unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL turn2 denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| validation-error v |> std/io:print.ln("FAIL turn2 invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL turn2 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL turn2 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL turn2 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL turn2 exhausted")
| partial p |> std/io:print.ln("FAIL turn2 partial")
| scope-not-found s2 |> std/io:print.ln("FAIL turn2 noscope {{ s2:s }}")

[with]std/bridge:create(id: "ca", scope: "api"): br
|> catchall-refused(br)
|> named-runs(br)

// Pins: a `|*` arm in interpreted source refuses — the turn answers
// `parse-error`, the dispatch never runs. The residual arm is a
// compiled-surface construct (its optional-only routing is a coverage-check
// promise); the interpreted surface has no coverage check, so the spelling
// is refused there outright. Interpreted text is the least-trusted writer
// in the system and cannot smuggle a residual case past the boundary.
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

// Turn 1: `|*` in the source text refuses at parse — surfaced as the
// turn's parse-error outcome.
tor residual-refused { br: *std/bridge:Bridge<session> }
residual-refused = std/bridge:run(br, source: "risky()\n| ok v |> _\n|* b |> _")
| result r |> std/io:print.ln("FAIL turn1 ran")
| error runerr |> std/bridge:error-decode(e: runerr)
    | parse-error p |> std/io:print.ln("turn1 parse-error — the spelling refuses")
    | event-denied ev |> std/io:print.ln("FAIL turn1 denied {{ ev:s }}")
    | validation-error v |> std/io:print.ln("FAIL turn1 invalid {{ v:s }}")
    | shape-error sh |> std/io:print.ln("FAIL turn1 shape {{ sh.message:s }}")
    | dispatch-error e |> std/io:print.ln("FAIL turn1 dispatch {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("FAIL turn1 exhausted")
    | scope-not-found s2 |> std/io:print.ln("FAIL turn1 noscope {{ s2:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL turn1 unhandled {{ ub.branch:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| defined d |> std/io:print.ln("FAIL turn1 defined {{ d:s }}")
| partial p |> std/io:print.ln("FAIL turn1 partial")

// Turn 2: control — named arms over the same dispatch still run.
tor named-runs { br: *std/bridge:Bridge<session> }
named-runs = std/bridge:run(br, source: "risky()\n| ok v |> _\n| missing m |> _")
| result r |> std/io:print.ln("turn2 named-arms result")
| error runerr |> std/bridge:error-decode(e: runerr)
    | parse-error p |> std/io:print.ln("FAIL turn2 parse {{ p.message:s }}")
    | event-denied ev |> std/io:print.ln("FAIL turn2 denied {{ ev:s }}")
    | validation-error v |> std/io:print.ln("FAIL turn2 invalid {{ v:s }}")
    | shape-error sh |> std/io:print.ln("FAIL turn2 shape {{ sh.message:s }}")
    | dispatch-error e |> std/io:print.ln("FAIL turn2 dispatch {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("FAIL turn2 exhausted")
    | scope-not-found s2 |> std/io:print.ln("FAIL turn2 noscope {{ s2:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL turn2 unhandled {{ ub.branch:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| defined d |> std/io:print.ln("FAIL turn2 defined {{ d:s }}")
| partial p |> std/io:print.ln("FAIL turn2 partial")

[with]std/bridge:create(id: "ca", scope: "api"): br
|> residual-refused(br)
|> named-runs(br)

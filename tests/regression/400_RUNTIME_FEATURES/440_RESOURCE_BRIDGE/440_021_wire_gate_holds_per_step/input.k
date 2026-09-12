// Pins: the wire gate holds PER ITEM inside a multi-item turn — the same
// shape rules a one-item turn is judged by. A bare value or a `when`
// clause mid-turn is a `step N/M parse-error` line, never a silent run.
//
// Before this pin the sequencing loop sent each item straight to
// run_event and only single-item turns passed parse_wire: a bare
// `count: 3` mid-turn dispatched, an unquoted unbound name became the
// literal string of itself, and `when false` ran the verb with a mangled
// argument. (kopium bridge-mirror rows: 2026-09-12-wire-gate-scope,
// 2026-09-12-when-guards)
import std/io
import std/bridge
import std/runtime

tor echo { text: string }
proc echo|zig {
    _ = @import("std").posix.write(1, text) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

std/runtime:register(scope: "api") {
    echo(1)
}

// One turn, three items: legal wire, bare value, `when` clause. Item 1
// runs; items 2 and 3 are per-step parse-errors — the turn continues
// past refusal, and the report names each step's verdict.
tor gated { br: *std/bridge:Bridge }
gated = std/bridge:run(br, source: "echo(text: \"a\")\necho(count: 3)\necho(text: \"b\") when true")
| partial p |> std/io:print.ln("{{ p.report:s }}")
| result r |> std/io:print.ln("FAIL result — a three-item turn is not a single result")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL turn-level parse {{ p.message:s }} — items refuse per step")
| validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL exhausted")
| scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")

[with]std/bridge:create(id: "wg", scope: "api"): br
|> gated(br)

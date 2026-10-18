// Pins: the retired colon form is refused in chain-step position too.
// `|> say: prose` used to parse as a branch constructor named `say:` with
// the prose as its plain value — the step silently never dispatched and
// the turn read `result` (kopium bridge-mirror 2026-10-18-colon-in-chain).
// A chain step is an invocation: `verb(field: value)` — a colon inside the
// step's head is not a branch name, and the line dies as a parse-error the
// model can see, the same verdict 440_046 pins at line head.
import std/io
import std/bridge
import std/runtime

tor read { path: string } -> string
proc read|zig {
    return "file-text";
}

tor say { text: string }
proc say|zig {
    _ = @import("std").posix.write(1, "say:") catch {};
    _ = @import("std").posix.write(1, text) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

std/runtime:register(scope: "api") {
    read(1)
    say(1)
}

tor gated { br: *std/bridge:Bridge<session>, source: string }
gated = std/bridge:run(br, source)
| result r |> std/io:print.ln("result")
| partial p |> std/io:print.ln("{{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
| residue r2 |> std/io:print.ln("FAIL residue")
| parse-error p |> std/io:print.ln("refused: {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL exhausted")
| scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")

// The swallow: say must not silently become a branch label.
[with]std/bridge:create(id: "cap", scope: "api"): br
|> gated(br, source: "read(path: \"x\") | ok t |> say: the prose")
// And the canonical spelling in the same seat stays live.
|> gated(br, source: "read(path: \"x\") | ok t |> say(text: \"held {{ t }}\")")

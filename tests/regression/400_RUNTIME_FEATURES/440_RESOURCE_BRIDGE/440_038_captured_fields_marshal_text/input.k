// Pins: a scope tor declaring captured fields marshals wire text through
// the interpreter dispatcher — `expr: Expression` arrives as a string
// carrying the captured expression text, `src: Source` arrives as a
// Source struct whose .text is the raw wire text. Quoted wire is the
// canonical form: the gate admits it today and the marshal routes it by
// declared field type, not by value shape.
//
// These are runtime fields — [comptime], [norun], and Program remain the
// only timing controls (400_202/400_203 pin the emitted-backend twin).
import std/io
import std/bridge
import std/runtime

tor calc { expr: Expression }
proc calc|zig {
    _ = @import("std").posix.write(1, "calc:") catch {};
    _ = @import("std").posix.write(1, expr) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

tor render { src: Source }
proc render|zig {
    _ = @import("std").posix.write(1, "render:") catch {};
    _ = @import("std").posix.write(1, src.text) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

std/runtime:register(scope: "api") {
    calc(1)
    render(1)
}

tor gated { br: *std/bridge:Bridge<session> }
gated = std/bridge:run(br, source: "calc(expr: \"2 + 3\")\nrender(src: \"hello world\")")
| partial p |> std/io:print.ln("{{ p.report:s }}")
| result r |> std/io:print.ln("FAIL result — a two-item turn reports per step")
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

[with]std/bridge:create(id: "cap", scope: "api"): br
|> gated(br)

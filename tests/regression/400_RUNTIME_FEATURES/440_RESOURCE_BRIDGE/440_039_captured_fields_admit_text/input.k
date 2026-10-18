// Pins: a bare wire value is a Koru expression, judged by the language's
// own expression parser — not by a field's declared type.
//
// `calc(expr: 2 + 3)` evaluates a bare expression to i64 5; `string`
// fields take quoted literals — `render(src: "hello world")`,
// `note(text: "thinking out loud")` — and refuse bare prose,
// `say(text: hello world)` being a parse-error: bare text is not a Koru
// expression.

import std/io
import std/bridge
import std/runtime

tor calc { expr: i64 }
proc calc|zig {
    _ = @import("std").posix.write(1, "calc:") catch {};
    const buf = @import("std").fmt.allocPrint(@import("std").heap.page_allocator, "{d}", .{expr}) catch unreachable;
    _ = @import("std").posix.write(1, buf) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

tor render { src: string }
proc render|zig {
    _ = @import("std").posix.write(1, "render:") catch {};
    _ = @import("std").posix.write(1, src) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

tor say { text: string } -> string
proc say|zig {
    return text;
}

std/runtime:register(scope: "api") {
    calc(1)
    render(1)
    say(1)
}

tor gated { br: *std/bridge:Bridge<session>, source: string }
gated = std/bridge:run(br, source)
| partial p |> std/io:print.ln("{{ p.report:s }}")
| result r |> std/io:print.ln("  single result")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("  refused: {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL exhausted")
| scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")

[with]std/bridge:create(id: "cap", scope: "api", introspection: true): br
|> gated(br, source: "calc(expr: 2 + 3)\nrender(src: \"hello world\")\nnote(text: \"thinking out loud\")")
|> gated(br, source: "say(text: hello world)")

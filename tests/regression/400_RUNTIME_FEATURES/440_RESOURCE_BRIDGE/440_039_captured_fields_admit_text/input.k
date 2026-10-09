// Pins: the wire gate is type-directed — a value position's declared field
// type decides what it admits.
//
// `expr: Expression` takes balanced expression text (`calc(expr: 2 + 3)`);
// `src: Source` takes raw text (`render(src: hello world)`); the colon
// form `verb: <rest>` fills a verb's lone Source field (`render: prose`,
// `note: prose`). The host verb `note` declares `text` Source, so
// `note(text: unquoted prose)` is wire. All of it normalizes to canonical
// quoted wire before the interpreter parser sees it — the proc receives
// identical text either spelling.
//
// An ordinary `string` field still refuses bare prose — `say(text: hello
// world)` is a parse-error, the control that keeps captured-text types a
// declaration, not a convention (440_038 pins the marshal beneath).

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
|> gated(br, source: "calc(expr: 2 + 3)\nrender(src: hello world)\nrender: raw prose here\nnote(text: thinking out loud)\nnote: colon form too")
|> gated(br, source: "say(text: hello world)")

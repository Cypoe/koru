// Pins: `verb: <prose>` is not wire — a call has one spelling and it
// carries parens: verb(field: value). A colon-headed line refuses as
// residue, every following prose line binds as its own residue item, and
// invocations in the same reply still run. There is no colon form to
// maintain — quoting is the quoting; a second spelling was a segmenter
// special-case that silently swallowed the same construct in chain steps.
import std/io
import std/bridge
import std/runtime

tor render { src: string }
proc render|zig {
    _ = @import("std").fs.File.stdout().writeAll("render:") catch {};
    _ = @import("std").fs.File.stdout().writeAll(src) catch {};
    _ = @import("std").fs.File.stdout().writeAll("\n") catch {};
}

tor shout { word: string }
proc shout|zig {
    _ = @import("std").fs.File.stdout().writeAll("shout:") catch {};
    _ = @import("std").fs.File.stdout().writeAll(word) catch {};
    _ = @import("std").fs.File.stdout().writeAll("\n") catch {};
}

std/runtime:register(scope: "api") {
    render(1)
    shout(1)
}

tor gated { br: *std/bridge:Bridge<session>, source: string }
gated = std/bridge:run(br, source)
| result r |> std/io:print.ln("ran")
| partial p |> std/io:print.ln("{{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
    | parse-error p |> std/io:print.ln("FAIL parse {{ p.message:s }}")
    | validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
    | shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
    | dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("FAIL exhausted")
    | scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")
| residue _ |> std/io:print.ln("residue, as it should be")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")

// `render:` and its prose continuations all bind residue; shout dispatches.
[with]std/bridge:create(id: "cap", scope: "api"): br
|> gated(br, source: "render: line1\n\nline2\nshout(word: \"hi\")")
// A `|`-arm line is not wire either — a lone arm binds residue.
|> gated(br, source: "render: a\n| ok u |>")
// An invocation-shaped `Note:` line is refused the same as the rest.
|> gated(br, source: "render: b\nNote: ends it")

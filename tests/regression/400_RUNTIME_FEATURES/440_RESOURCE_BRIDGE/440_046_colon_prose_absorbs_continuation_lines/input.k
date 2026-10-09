// Pins: a `verb: <prose>` colon item is a block — following lines that are
// not invocation heads fold into the prose instead of splitting into
// residue items. The block ends at the next `name(`, `name:`, `|`, or
// `tor ` line; blank lines inside it are preserved. Before this, every
// continuation line after a colon head opened its own item and bound as
// residue — a multi-line `say:` delivered only its first line to the user.
import std/io
import std/bridge
import std/runtime

tor render { src: Source }
proc render|zig {
    _ = @import("std").posix.write(1, "render:") catch {};
    _ = @import("std").posix.write(1, src.text) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

tor shout { word: string }
proc shout|zig {
    _ = @import("std").posix.write(1, "shout:") catch {};
    _ = @import("std").posix.write(1, word) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
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
| event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL exhausted")
| scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")

// Colon block: two prose lines (one blank line between) fold into src.
[with]std/bridge:create(id: "cap", scope: "api"): br
|> gated(br, source: "render: line1\n\nline2\nshout(word: \"hi\")")
// A `|`-arm line ends the block and stands alone — a lone arm is not wire.
|> gated(br, source: "render: a\n| ok u |>")
// A `word:` line ends the block — invocation-shaped, even if unknown.
|> gated(br, source: "render: b\nNote: ends it")

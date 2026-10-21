// Pins: a quoted wire value carrying RAW newlines still delivers its text —
// the scanner canonicalizes it to \n escapes instead of copying verbatim.
// Before the fix a multi-line quoted `src:` evaluated to "" — the proc saw
// an empty field and downstream emitters shipped empty output (measured
// kopium task2 2026-10-06: say(text: "<three paragraphs>") emitted
// {"kind":"say","text":""} and the marshal's message validator killed
// the run). Escaped \n literals keep working — they were already canonical.
import std/io
import std/bridge
import std/runtime

tor render { src: string }
proc render|zig {
    _ = @import("std").fs.File.stdout().writeAll("render:") catch {};
    _ = @import("std").fs.File.stdout().writeAll(src) catch {};
    _ = @import("std").fs.File.stdout().writeAll("\n") catch {};
}

std/runtime:register(scope: "api") {
    render(1)
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
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")

// Raw newline inside the quoted value — the shape that lost its text.
[with]std/bridge:create(id: "cap", scope: "api"): br
|> gated(br, source: "render(src: \"line1\nline2)\")")
// Control: the escaped-\n spelling was already canonical.
|> gated(br, source: "render(src: \"line3\\nline4\")")

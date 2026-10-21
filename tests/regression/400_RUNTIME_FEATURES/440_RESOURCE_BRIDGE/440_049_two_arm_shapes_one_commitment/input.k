// Pins: the wire's two arm shapes and the commitment rule between them.
//
//   Single-line — predicted branches ride the call's own line; a `|` in
//   that line commits the program to one line, so a `|` arm on a later
//   line has nothing to hang on and the turn refuses (turn 3).
//   Multi-line — a bare call line with each `|` arm on its own indented
//   line; deeper indent arms a mid-chain step (turn 4); arming a subset
//   of branches is legal — an unnamed branch stops the turn as
//   `unhandled-branch` (turn 5).
import std/io
import std/bridge
import std/runtime

tor read { path: string }
| ok string
| missing string
proc read|zig {
    if (@import("std").mem.eql(u8, path, "found")) return .{ .ok = "file-text" };
    return .{ .missing = path };
}

tor say { text: string }
proc say|zig {
    _ = @import("std").fs.File.stdout().writeAll("say:") catch {};
    _ = @import("std").fs.File.stdout().writeAll(text) catch {};
    _ = @import("std").fs.File.stdout().writeAll("\n") catch {};
}

std/runtime:register(scope: "api") {
    read(1)
    say(1)
}

tor run-src { br: *std/bridge:Bridge<session>, source: string, tag: string }
run-src = std/bridge:run(br, source)
| result r |> std/io:print.ln("{{ tag:s }} result")
| unhandled-branch ub |> std/io:print.ln("{{ tag:s }} unhandled {{ ub.branch:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | parse-error p |> std/io:print.ln("{{ tag:s }} parse-error {{ p.message:s }}")
    | validation-error v |> std/io:print.ln("{{ tag:s }} FAIL invalid")
    | shape-error sh |> std/io:print.ln("{{ tag:s }} FAIL shape")
    | dispatch-error e |> std/io:print.ln("{{ tag:s }} FAIL dispatch {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("{{ tag:s }} FAIL exhausted")
    | event-denied ev |> std/io:print.ln("{{ tag:s }} FAIL denied")
    | scope-not-found s2 |> std/io:print.ln("{{ tag:s }} FAIL noscope")
| residue r2 |> std/io:print.ln("{{ tag:s }} FAIL residue")
| defined d |> std/io:print.ln("{{ tag:s }} FAIL defined")
| partial p |> std/io:print.ln("{{ tag:s }} FAIL partial")

// Turn 1 — inline: both predicted branches ride the head's line.
// Turn 2 — multi-line: each branch on its own indented line.
// Turn 3 — mixed: a `|` on the head's line, then an indented `|` line —
//          the commitment is refused with a teaching parse-error.
// Turn 4 — deeper indent arms the interior step: the inner read's
//          `missing` fires, not the head's.
// Turn 5 — multi-line partial: only `missing` is armed; `ok` comes back
//          as `unhandled-branch` with the branch name and payload.
[with]std/bridge:create(id: "c", scope: "api"): br
|> run-src(br, source: "read(path: \"gone\") | ok t |> say(text: \"ok {{ t }}\") | missing m |> say(text: \"miss {{ m }}\")", tag: "t1-inline")
|> run-src(br, source: "read(path: \"found\")\n    | ok t |> say(text: \"ok {{ t }}\")\n    | missing m |> say(text: \"miss {{ m }}\")", tag: "t2-multiline")
|> run-src(br, source: "read(path: \"gone\") | ok t |> say(text: \"ok {{ t }}\")\n    | missing m |> say(text: \"miss {{ m }}\")", tag: "t3-mixed")
|> run-src(br, source: "read(path: \"found\")\n    | ok t |> read(path: t)\n        | ok t2 |> say(text: \"inner ok\")\n        | missing m2 |> say(text: \"inner miss\")\n    | missing m |> say(text: \"outer miss\")", tag: "t4-interior")
|> run-src(br, source: "read(path: \"found\")\n    | missing m |> say(text: \"miss {{ m }}\")", tag: "t5-partial")

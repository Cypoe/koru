// TEST: a narration line carrying an apostrophe ("I'll check") above a wire
// call segments as TWO items — the prose binds residue, the call runs. The
// turn segmenter must not treat `'` as a string delimiter: wire strings are
// double-quoted only (runtime.wirescan.kz makes the same ruling), and a
// contraction's apostrophe is a character. Before the fix, the unclosed `'`
// string state carried across the newline and swallowed the wire item into
// one unparseable blob — the whole turn bound as residue and nothing ran.
// A lone prose line with an apostrophe still binds whole-reply residue.
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

tor turn { br: *std/bridge:Bridge<session>, src: string }
turn = std/bridge:run(br, source: src)
| result r |> std/io:print.ln("RESULT bound={{ r.bound:s }}")
| partial p |> std/io:print.ln("{{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
    | parse-error p |> std/io:print.ln("PARSE {{ p.message:s }}")
    | validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
    | shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
    | dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("FAIL exhausted")
    | scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")
| residue r |> std/io:print.ln("RESIDUE {{ r.report:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")

[with]std/bridge:create(id: "ap", scope: "api"): br
|> turn(br, src: "I'll echo the greeting next.\necho(text: \"hi\")")
|> turn(br, src: "it's just prose")
|> turn(br, src: "echo(text: \"it's quoted fine\")")

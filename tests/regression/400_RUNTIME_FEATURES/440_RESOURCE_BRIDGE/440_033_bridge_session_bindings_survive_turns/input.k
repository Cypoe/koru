// TEST: a result bound on one turn is referenceable on the next.
//
// The wire is a session, not a transcript of one-shot runs — `env.clear()`
// per run is correct for arm bindings, but a dispatched RESULT is session
// state. `run` auto-binds every result `r{N}` into the bridge's session
// env and reports the name (`bound`); a later `run` seeds its env from it,
// so `r1.text` resolves turns after the value landed. `bind(name:,
// value:)` is the host verb for values arriving out-of-band. A name no
// turn ever bound still fails loudly with the teaching error.

import std/io
import std/bridge
import std/runtime
import std/interpreter

tor produce {} -> string
proc produce|zig {
    const std = @import("std");
    const S = struct { threadlocal var buf: [96]u8 = undefined; };
    return std.fmt.bufPrint(&S.buf, "{{\"text\": \"payload-7\", \"count\": 7}}", .{}) catch unreachable;
}

tor echo { text: string }
proc echo|zig {
    _ = @import("std").posix.write(1, text) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

std/runtime:register(scope: "api") {
    produce(1)
    echo(1)
}

tor turn { br: *std/bridge:Bridge, src: string }
turn = std/bridge:run(br, source: src)
| result r |> std/io:print.ln("RESULT bound={{ r.bound:s }}")
| partial p |> std/io:print.ln("FAIL partial {{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("REFUSED {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL exhausted")
| scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")

tor show-vocab { br: *std/bridge:Bridge }
show-vocab = std/bridge:vocabulary(br)
| ok v |> std/io:print.ln("{{ v:s }}")
| not-found nf |> std/io:print.ln("FAIL noscope {{ nf:s }}")

[with]std/bridge:create(id: "xb", scope: "api", introspection: true): br
|> turn(br, src: "produce()")
|> turn(br, src: "echo(text: r1.text)")
|> turn(br, src: "echo(text: r1.count)")
|> turn(br, src: "bind(name: \"user\", value: \"{\\\"uid\\\": \\\"sara_doe_496\\\"}\")")
|> turn(br, src: "echo(text: user.uid)")
|> turn(br, src: "echo(text: r9)")
|> show-vocab(br)

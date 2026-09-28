// TEST: prose on the wire is residue — bound into the session, never
// destroyed. A turn that is all prose comes back `residue` (nothing ran)
// carrying one binding — even a MULTI-LINE prose turn coalesces into a
// single `residue bound: r{N}` (the model meant one utterance, and
// redelivery must not take N calls). The bound text is a scalar `r{N}`
// value, so `echo(text: r1)` re-emits the model's own words through a
// real verb. In a mixed turn a refused item is a `step N/M residue
// bound:` line inside `partial`. A malformed invocation is NOT residue:
// it lexed as a call and broke inside the arguments — a plain parse-error.
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

tor turn { br: *std/bridge:Bridge, src: string }
turn = std/bridge:run(br, source: src)
| result r |> std/io:print.ln("RESULT bound={{ r.bound:s }}")
| partial p |> std/io:print.ln("{{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
| residue r |> std/io:print.ln("RESIDUE {{ r:s }}")
| parse-error p |> std/io:print.ln("PARSE {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL exhausted")
| scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")

[with]std/bridge:create(id: "rs", scope: "api"): br
|> turn(br, src: "I cannot delete files for you.")
|> turn(br, src: "echo(text: r1)")
|> turn(br, src: "echo(text: \"a\")\nlet me apologize properly")
|> turn(br, src: "echo(text: r4)")
|> turn(br, src: "echo(text: oops x)")
|> turn(br, src: "first apology\nsecond apology")
|> turn(br, src: "echo(text: r6)")

// Pins: strict typed-argument dispatch. A bare literal that does not parse to
// the declared type is refused at dispatch with a teaching error naming the
// field, the expected type, and the raw text — `catch 0` coercion is gone.
// A missing declared field lands the same refusal (raw = ""), so absent
// params are never silently zeroed either.
import std/io
import std/bridge
import std/runtime

tor add { a: i64, b: i64 } -> i64
proc add|zig {
    return a + b;
}

std/runtime:register(scope: "api") {
    add(1)
}

tor turn { br: *std/bridge:Bridge, src: string }
turn = std/bridge:run(br, source: src)
| result _ |> std/io:print.ln("RESULT")
| dispatch-error e |> std/io:print.ln("DISPATCH {{ e.message:s }}")
| unhandled-branch ub |> std/io:print.ln("UNHANDLED {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("PARSE {{ p.message:s }}")
| validation-error v |> std/io:print.ln("INVALID {{ v:s }}")
| shape-error sh |> std/io:print.ln("SHAPE {{ sh.message:s }}")
| partial p |> std/io:print.ln("PARTIAL")
| defined d |> std/io:print.ln("DEFINED {{ d:s }}")
| exhausted _ |> std/io:print.ln("EXHAUSTED")
| scope-not-found s2 |> std/io:print.ln("NOSCOPE {{ s2:s }}")

[with]std/bridge:create(id: "tg", scope: "api"): br
|> turn(br, src: "add(a: \"five\", b: 3)")
|> turn(br, src: "add(b: 3)")
|> turn(br, src: "add(a: 2, b: 3)")

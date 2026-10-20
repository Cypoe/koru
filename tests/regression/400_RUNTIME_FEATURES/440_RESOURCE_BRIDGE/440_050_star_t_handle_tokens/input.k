// Pins: a collected `*T` tor mints an opaque resource token — the wire
// never sees a pointer, only "h:Res:N". `use` resolves the token to the
// real pointer (its proc prints a field only the live struct has), a
// token spelled literally in the source resolves identically, a made-up
// token refuses at the gate, and a post-discharge token refuses as spent.
// Handles are identities minted by the pool, not binding positions.
import std/io
import std/bridge
import std/runtime
import reslib/res

std/runtime:register(scope: "res") {
    reslib.res:mint -> mint(1)
    reslib.res:grab -> grab(1)
    reslib.res:release -> release(1)
}

tor drive { br: *std/bridge:Bridge<session> }
drive = std/bridge:run(br, source: "mint() | ok h |>\ngrab(r: h) | ok _ |>\ngrab(r: \"h:Res:1\") | ok _ |>\ngrab(r: \"h:bogus:9\") | ok _ |>\nrelease(r: h) | ok _ |>\ngrab(r: h) | ok _ |>")
| partial p |> std/io:print.ln("{{ p.report:s }}")
| result r |> std/io:print.ln("{{ r.trace:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error p |> std/io:print.ln("FAIL turn-level parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL exhausted")
| scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")

[with]std/bridge:create(id: "tok", scope: "res"): br
|> drive(br)

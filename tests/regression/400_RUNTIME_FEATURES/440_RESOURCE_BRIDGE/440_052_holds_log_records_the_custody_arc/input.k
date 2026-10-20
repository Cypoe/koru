// Pins: a world-mounted bridge keeps the custody ledger — one
// tab-separated line per custody event in <world>/holds.log:
//
//   session-open    t=<ms>  session=<id>
//   mint            t=<ms>  session=<id>  handle=<tok>  verb=<event>  type=<T>  subject=<args>
//   release         t=<ms>  session=<id>  handle=<tok>  by=<discharge event>
//   session-closed  t=<ms>  session=<id>
//
// The log is the successor's read of custody: a mint inside a closed
// span with no release was released at hang-up; a mint with no
// session-closed after it died holding. Minted tokens are seeded hex
// and never printed — post.sh pins the FIELD SHAPE (tab names, digit
// timestamps, h:Res:<6hex>, mint/release carrying the same handle).

import std/io
import std/bridge
import std/runtime
import reslib/res

std/runtime:register(scope: "res") {
    reslib.res:mint -> mint(1)
    reslib.res:grab -> grab(1)
    reslib.res:release -> release(1)
}

tor step-quiet { br: *std/bridge:Bridge<session>, source: string<*>, tag: string }
step-quiet = std/bridge:run(br, source)
| result r |> std/io:print.ln("{{ tag:s }}: ok (holds {{ r.handles:d }})")
| unhandled-branch ub |> std/io:print.ln("{{ tag:s }} FAIL unhandled {{ ub.branch:s }}")
| defined d |> std/io:print.ln("{{ tag:s }} FAIL defined {{ d:s }}")
| dispatch-error e |> std/io:print.ln("{{ tag:s }} FAIL dispatch {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("{{ tag:s }} FAIL denied {{ ev:s }}")
| residue _ |> std/io:print.ln("{{ tag:s }} FAIL residue outcome")
| parse-error p |> std/io:print.ln("{{ tag:s }} FAIL parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("{{ tag:s }} FAIL invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("{{ tag:s }} FAIL shape {{ sh.message:s }}")
| exhausted _ |> std/io:print.ln("{{ tag:s }} FAIL exhausted")
| scope-not-found s2 |> std/io:print.ln("{{ tag:s }} FAIL noscope {{ s2:s }}")
| partial p |> std/io:print.ln("{{ tag:s }} FAIL unexpected partial")

[with]std/bridge:create(id: "w1", scope: "res", world: "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_052_holds_log_records_the_custody_arc/world"): br
|> std/io:print.ln("--- session w1 open")
|> step-quiet(br, source: "mint() | ok h |>", tag: "mint")
|> step-quiet(br, source: "release(r: r1)", tag: "release")
|> std/bridge:close(br)
|> std/io:print.ln("--- session w1 closed")

// A worldless bridge keeps no ledger — post.sh also pins that nothing
// lands in the test dir from this span.
[with]std/bridge:create(id: "w2", scope: "res"): br2
|> step-quiet(br: br2, source: "mint() | ok h |>", tag: "w2-mint")
|> step-quiet(br: br2, source: "release(r: r1)", tag: "w2-release")
|> std/bridge:close(br: br2)

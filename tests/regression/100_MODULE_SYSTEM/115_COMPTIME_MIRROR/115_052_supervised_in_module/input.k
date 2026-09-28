// MIRROR for `std/supervisor:supervised`: the supervised retry fold sits on
// a branch arm inside an imported module — `app/lib` owns the ring, the
// supervised child `attempt`, and the `push` tor that supervises it; the
// entry composes by qualified name. The fold emits re-entry units and this
// is the test that can see whether they qualify through the module's
// import-derived name — the entry file collapses file-name and module-name
// into one, so the 320_110 control cannot tell a correct qualifier from a
// lucky one.
import app/lib
import std/io

app/lib:seed()
| ok |> app/lib:push(x: 10)
    | ok |> std/io:print.ln("ERROR: enqueued into full ring")
    | full |> std/io:print.ln("mod gave up")
| full |> std/io:print.ln("ERROR: seed")

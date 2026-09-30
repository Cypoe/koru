// OWED: composite custody. A kind's proto carries TWO owned leaves —
// `r1`/`r2` are each `*Resource<owned!>`, two independent debts inside one
// value. `send | ok` consumes both at the producer; the winning `! env`
// arm mints `v.r1` and `v.r2` separately and settles each through the
// type's own discharger. The channel moves a leaf bundle, not a blob:
// custody deconstructs at the boundary and must account for every path.
import std/io
import std/proto
import std/channel
import std/pump
import app/lib/res

std/proto(Env) {
    r1: *app/lib/res:Resource<owned!>
    r2: *app/lib/res:Resource<owned!>
}

pub tor mk-env { a: *app/lib/res:Resource<!owned>, b: *app/lib/res:Resource<!owned> } -> Env
mk-env -> { r1: a, r2: b }

std/channel:new(inbox, capacity: 8) { env: Env }

std/channel(inbox)
! env v |> app/lib/res:free(r: v.r1) |> app/lib/res:free(r: v.r2) |> std/io:print.ln("env settled")

app/lib/res:new(): a |> app/lib/res:new(): b |> mk-env(a, b): e |> std/channel:send(inbox, e)
| ok |> std/channel:close(inbox)
    | ok |> std/io:print.ln("sealed")
| full |> app/lib/res:free(r: e.r1) |> app/lib/res:free(r: e.r2) |> std/io:print.ln("full")
| closed |> app/lib/res:free(r: e.r1) |> app/lib/res:free(r: e.r2) |> std/io:print.ln("closed")

std/pump:create(main)
| drained |> std/io:print.ln("drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump:run(main)

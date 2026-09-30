// OWED across `<:`: proto extension is field-set union, and owned leaves
// ride the merge. `Env <: Base` inherits `r1`'s debt and adds `r2`'s — the
// channel transits both: `send | ok` consumes `e.r1` AND `e.r2`; the `! env`
// arm mints `v.r1`/`v.r2` and settles each through the discharger. The
// registry's merge is the shape; custody follows every leaf it carries.
import std/io
import std/proto
import std/channel
import std/pump
import app/lib/res

std/proto(Base) {
    r1: *app/lib/res:Resource<owned!>
}

std/proto(Env <: Base) {
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

// OWED refusal: composite custody is per-path — an arm that settles only
// `v.r1` while `v.r2` stands undischarged must refuse. The debts are
// independent leaves; settling one does not settle the bundle. Sibling of
// 699_027 (whole-value must-discharge) and 699_031 (full settle).
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
! env v |> app/lib/res:free(r: v.r1) |> std/io:print.ln("leaked r2")

app/lib/res:new(): a |> app/lib/res:new(): b |> mk-env(a, b): e |> std/channel:send(inbox, e)
| ok |> std/io:print.ln("sent")
| full |> app/lib/res:free(r: e.r1) |> app/lib/res:free(r: e.r2) |> std/io:print.ln("full")
| closed |> app/lib/res:free(r: e.r1) |> app/lib/res:free(r: e.r2) |> std/io:print.ln("closed")

std/pump:create(main)
| drained |> std/io:print.ln("drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump:run(main)

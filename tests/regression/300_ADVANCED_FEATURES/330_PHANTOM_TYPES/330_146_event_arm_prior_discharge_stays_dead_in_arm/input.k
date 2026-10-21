// 330_146 — a binding discharged by an EARLIER call stays dead inside a
// `!` arm of a LATER call.
//
// `pump(w1)` consumes w1's obligations; on `| done` the loop has returned
// them and `close(d1)` settles the re-issued `active!`. w1 itself is
// discharged — the custody that made it live belonged to the FIRST pump's
// `! tick`. Inside the SECOND pump's `! tick`, only w2 (that call's own
// consumed argument) is live; reading w1 is use-after-discharge.
import app/win
import std/io

app/win:open()
| win w1 |> app/win:pump(w: w1)
    ! tick _ |> app/win:read(w: w1)
    | done d1 |> app/win:close(w: d1)
        |> app/win:open()
        | win w2 |> app/win:pump(w: w2)
            ! tick _ |> app/win:read(w: w1)
            | done d2 |> app/win:close(w: d2)
        | err e2 |> std/io:print.ln(e2)
| err e |> std/io:print.ln(e)

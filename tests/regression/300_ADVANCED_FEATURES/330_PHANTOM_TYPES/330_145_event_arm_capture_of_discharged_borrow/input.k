// 330_145 — `!`-arm custody of a binding the firing call consumed
//
// `pump(w)` takes `*Win<!opened|!active>` — w's obligations move into the
// loop's custody for the call's duration. Inside `! tick` the loop
// still holds w: the binding reads as live `*Win<opened|active>` (the
// consumed phantom minus the `!` markers), which is exactly what `read`'s
// signature borrows. On the `| done` path the loop hands `active!` back and
// `close` settles it.
//
// What this pins: an ambient use of the consumed binding inside its own
// `!` arm is legal — custody, not capture shape. The companion refusal
// (a binding discharged by an EARLIER call stays dead inside the arm) is
// 330_146. Post-call use after `| done` remains use-after-discharge.
import app/win
import std/io

app/win:open()
| win w |> app/win:pump(w)
    ! tick _ |> app/win:read(w)
    | done w2 |> app/win:close(w: w2) |> std/io:print.ln("closed")
| err e |> std/io:print.ln(e)

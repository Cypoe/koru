// PINS the C-lane refusal axis for concurrency — verification-path
// refusal row 3: "pump / rings / worker.spawn | CompCert is a sequential
// C subset; no verified concurrency".
//
// Shape cloned from 115_049_pump_run_in_module: a `std/pump` join + run
// whose participant lives in an imported module. Co-present axes under
// --lang=c: `!` effect arms (row 2), raw Zig host lines in app/lib
// (row 1), `[transform]` procs inside std/pump itself (row-4-adjacent),
// and zig-only verb impls with no `|c` variant. Which reason an emitter
// reports first is a design call; this pin asserts the concurrency
// reason is the one named.
import std/io
import std/pump
import app/lib

std/pump:create(main)
| drained |> std/io:print.ln("pump drained")

std/pump(main)
! step |> app/lib:step()
    ! stepped c |> std/io:print.ln("single stepped {{ c:d }}")
! live |> app/lib:live()
! wait i |> app/lib:wait(i)

std/pump:run(main)

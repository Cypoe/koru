// Test: `koruc explain` answers for a program the compiler REFUSES —
// explain runs on the pre-transform tree, so an orphan join (no
// `std/pump:create`) and a `! wait` without `! live` still report with
// the same refusal reasons the transform raises. post.sh asserts the
// report; MUST_ERROR pins that the compiler still refuses the program.
import std/io
import std/pump
import std/explain

// orphan join — no pump named 'ghost' is ever created
std/pump(ghost)
! step |> step()

std/pump:create(main)

// `! wait` without `! live` — interests are indexed 0..live()
std/pump(main)
! step |> step()
! wait i |> wait(i)

std/pump:run(main)

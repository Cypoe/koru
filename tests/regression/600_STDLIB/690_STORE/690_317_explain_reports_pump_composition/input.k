// Test: `koruc explain` on a pump — std/pump's explainer folds the
// create/join/run sites in document order and reports the composition:
// participants in join order, the verbs each answers, drain policy
// (every `live` answered → the pump retires), the idle policy (no `!
// idle` arm + a `wait` verb → the union wait), and the `| drained` arm.
// The fold reuses the transforms' own checks — PH.calleeDecl and the
// verb contract — so the report cannot drift from what run emits.
// post.sh drives both the text rows and the typed json catalog; the
// program itself drains in 3 steps (MUST_RUN proves the report true).
import std/io
import std/pump
import std/explain

std/pump:create(main)
| drained |> std/io:print.ln("pump drained")

std/pump(main)
! step |> step()
! live |> live()
! wait i |> wait(i)

std/pump:run(main)

// PINS nested template resolution: an `if` inside a `for`s `! each` arm —
// the arm body is itself template-rendered, so the emitter resolves markers
// recursively across two inline bodies and two continuation lists. This is
// the control-flow skeleton the prime-sieve marking loop uses.
import std/io

for(0..4)
! each i |> if(i > 1)
    | then |> std/io:print.ln("big {{ i:d }}")
    | else |> std/io:print.ln("small {{ i:d }}")
| done |> std/io:print.ln("done")

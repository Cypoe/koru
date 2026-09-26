// ARM AT THE CAPTURE LEVEL SILENTLY DROPPED (pure .k).
//
// `ticker`'s `| done` arm is written at the capture level (column 0) instead
// of inside the `! as s` continuation where `ticker(...)` is called. Arm
// attachment is positional: arms beside `capture` belong to capture's branch
// set (`| captured`), and `| done` is not one of them.
//
// Current behavior (the bug): the `| done d` arm vanishes — its body never
// emits, no diagnostic fires, and `ticker`'s declared `| done usize`
// terminal is auto-discarded at emission (`_ = __koru_eff_disc_0`). Two
// exhaustiveness holes at once: an undeclared arm on `capture` is accepted,
// and a required terminal on `ticker` goes unhandled without KORU021.
//
// Expected (when fixed): either the arm binds to `ticker` and the program
// prints `done 3` then `hits 3`, or the compiler refuses the shape with a
// diagnostic — both rulings close the silent drop. This pin expects the
// binding interpretation's output.
import std/io
import std/control

pub tor ticker { n: usize }
! tick usize
| done usize

ticker = for(0..n)
! each i |> tick(i)
| done => done n

capture { hits: 0[i64] }
! as s |> ticker(n: 3)
    ! tick _ |> captured { hits: s.hits + 1 }
| done d |> std/io:print.ln("done {{ d:d }}")
| captured fin |> std/io:print.ln("hits {{ fin.hits:d }}")

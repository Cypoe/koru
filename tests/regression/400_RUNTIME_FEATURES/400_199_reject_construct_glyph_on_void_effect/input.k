// Glyph discipline (KORU102), the VOID case — sibling of 400_122 (`=>` on a
// `-> T` resume) and 400_126 (`=>` naming an undeclared resume arm). `=>`
// CONSTRUCTS a branch of the handled effect's resume sum; an effect declared
// `! beat <payload>` has NO resume value and NO arms, so there is nothing to
// construct and the construct has nowhere to live — the enclosing tor's
// branches are only reachable from the call's own `| done` branch. Without
// this wall the program sails through checking and dies in emitted Zig
// ("type 'void' does not support struct initialization syntax" inside the
// synthesized handler, plus "implicitly returns" on the outer tor).
// Pure-.k realization of the shape kopium's wired/holes/10 surfaced.
import std/io
import std/control

pub tor beats { n: usize }
! beat usize
| done usize

beats = for(0..n)
! each i |> beat(i)
| done => done n

tor drive {}
| ran
| rejected

drive = beats(n: 2)
! beat _ => ran
| done _ => rejected

drive()
| ran |> std/io:print.ln("RAN")
| rejected |> std/io:print.ln("REJ")

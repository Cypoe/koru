// RED PIN — `| captured` arm bodies escape unknown-branch checking.
//
// `| missing` is not a branch of `std/control:if` — inside a `for`'s
// `| done` arm the identical shape refuses KORU021 "has no branch
// 'missing' (available: then, else)". Inside `| captured` it compiles
// green and the emitter renders the arm as an empty `else` — the arm's
// steps are silently dropped (they carried unbound names in the fuzz
// finding this pins: .kfuzz/findings_gp/gp_1_pass).
//
// The capture transform consumes the `| captured` subtree; whatever
// replaces it is never re-walked for branch coverage. Stays red until
// transform-produced subtrees get the same unknown-branch check as
// source-written ones.

import std/io
import std/field

std/field:new(bits: 8)
| field f |> for(1..4)
    ! each i |> std/field:set(f, i)
    | done |> capture { hits: 0[i64] }
        ! as a |> for(0..2)
            ! each x |> captured { hits: a.hits + x }
        | captured r |> if(r.hits == 0)
            | then |> std/io:print.ln("then")
            | missing |> std/io:print.ln("should-refuse")
| err e |> _

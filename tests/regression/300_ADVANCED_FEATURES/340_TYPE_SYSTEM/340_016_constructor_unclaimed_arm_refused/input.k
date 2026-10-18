// PINS: the REFUSAL of an unclaimed `| done` branch arm on a
// `std/constructor` transform site — the general-form twin of
// 690_364/690_370 (store sites). `constructor` claims exactly
// `! construct` and `| constructed`; its declared branch contract is
// DOCS ONLY at a transform site — the shape checker runs after
// transforms and only ever sees the replacement. Written anyway, the
// arm parses, the replacement is built from `constructed` alone, and
// the arm evaporates: it NEVER runs and no diagnostic says so.
// ast_functional.unclaimedContinuation refuses it by name.

import std/io
import std/constructor

std/constructor(nums)
! construct |> for(1..4)
    ! each x |> std/constructor:push(x)
| constructed built |> for(built)
    ! each n |> std/io:print.ln("n={{ n:d }}")
| done |> std/io:print.ln("never")

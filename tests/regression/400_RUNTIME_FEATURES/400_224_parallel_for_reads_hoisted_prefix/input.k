import std/io

// Pins: a [parallel]for whose each body still reads a binding the invariant
// hoist lifted out of the loop. `dbl(x: 5): c` is item-independent, so the
// hoist runs it once before the for — but the parallel lowering emits the
// each body inside a worker fn where enclosing consts are invisible (and
// unshadowable). The lifted bindings the body still references are passed in
// as a worker environment (@hoisted-env marks -> __koru_par_env param).
// Before the fix this failed at emission with "mutable 'g' not accessible
// from here" / "'c' not accessible from inner function". Oracle: dbl(5)=10
// folded 4 times = 40.

tor dbl { x: i64 } -> i64
dbl = if(x > 0)
    | then -> x + x
    | else -> 0

capture { acc: 0[i64] }
! as g |> [parallel]for(0..4)
    ! each _ |> dbl(x: 5): c |> captured { acc: g.acc + c }
| captured res |> std/io:print.ln("{{ res.acc:d }}")

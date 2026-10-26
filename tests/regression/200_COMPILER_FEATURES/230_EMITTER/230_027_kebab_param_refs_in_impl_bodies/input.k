// TEST: kebab-case input field references inside impl bodies
//
// A tor param spelled `a-b` destructures to `const a_b` in the emitted
// handler, but references in impl bodies used to pass through verbatim —
// escapeBoundNames only rewrote names carried in zig_scope_bindings, and
// event input fields were never registered there. `return a-b - c` reached
// Zig as subtraction of undeclareds; `x-y` in a guard the same.
//
// Pins both impl shapes: bare return (`f -> a-b - c`, `g -> a-b`) and a
// flow body with the kebab name in a guard and in arm produce values.

import std/io

tor f { a-b: i64, c: i64 } -> i64
f -> a-b - c

tor g { a-b: i64, c: i64 } -> i64
g -> a-b

tor bump { x-y: i64 } -> i64
bump = if(x-y > 0)
    | then -> x-y + 1
    | else -> 0 - x-y

f(a-b: 10, c: 3): r |> std/io:print.ln("{{ r:d }}")
|> g(a-b: 10, c: 3): q |> std/io:print.ln("{{ q:d }}")
|> bump(x-y: 10): s |> std/io:print.ln("{{ s:d }}")
|> bump(x-y: 0 - 5): t |> std/io:print.ln("{{ t:d }}")

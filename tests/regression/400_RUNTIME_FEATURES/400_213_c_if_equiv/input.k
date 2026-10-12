// PINS the C lane `if` template: `if(<c_lowered expr>)` renders a C if/else
// whose then/else arms splice through `__koru_continue_N` markers — the
// continuation-index resolution the emitter owns, with the guard left on
// the template side.
import std/io

if(1 == 1)
| then |> std/io:print.ln("then")
| else |> std/io:print.ln("else")

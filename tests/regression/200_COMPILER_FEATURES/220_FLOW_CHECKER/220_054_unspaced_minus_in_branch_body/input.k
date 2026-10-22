// TEST: unspaced `-` between bound names inside a control-flow branch body
//
// 220_052 pins the produce carrier; this pins the same ruling inside a
// conditional's named branch (`| then -> q-b`). Branch bodies are nested
// AST — the checker must descend through conditional/foreach/switch branch
// lists to see their expressions, or the token slips past and Zig reads
// subtraction silently.

import std/io

tor diff { q: i64, b: i64 } -> i64
diff = if(q > 0)
    | then -> q-b
    | else -> 0

diff(q: 10, b: 3): r |> std/io:print.ln("{{ r:d }}")

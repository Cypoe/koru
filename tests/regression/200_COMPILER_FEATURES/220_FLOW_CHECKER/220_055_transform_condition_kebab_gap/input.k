// TEST: transform-captured conditions are outside KORU181's reach — GAP PIN
//
// `if(...)` is a transform: its argument arrives as captured source
// (expression_value), and the unbound-name scan does not open captured
// expression args. So `q-b > 0` here reaches Zig verbatim, where the host
// reads `q - b` — the program compiles and prints the subtraction answer.
//
// This test is GREEN while the gap exists and is the tripwire for fixing
// it: if the checker ever opens transform condition args, KORU181 fires
// here and this test goes red — at which point it should be repinned as a
// MUST_ERROR twin of 220_054.

import std/io

tor diff { q: i64, b: i64 } -> i64
diff = if(q-b > 0)
    | then -> 1
    | else -> 0

diff(q: 10, b: 3): r |> std/io:print.ln("{{ r:d }}")

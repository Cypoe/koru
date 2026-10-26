// TEST: unspaced `-` between bound names reads as one kebab identifier
//
// `-` is a name glyph in Koru, so `q-b` in expression position is ONE
// identifier, not subtraction. When no `q-b` is declared but both `q` and
// `b` resolve, the author almost surely wrote subtraction and the checker
// teaches the spaced spelling instead of letting the token reach Zig.

import std/io

tor pick { } | done i64 | miss
pick => done 1

tor diff { q: i64, b: i64 } -> i64
diff = pick
    | done _ -> q-b
    | miss -> 0

diff(q: 10, b: 3): r |> std/io:print.ln("{{ r:d }}")

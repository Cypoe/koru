// Narrow int casts: `@as(u6, @intCast(n))` range-checks like zig — in-range
// values pass through, and the C lane spells `__koru_intcast(v, 0, 63)`
// rather than silently truncating. u6 rides in a uint8_t cell; the cast is
// what bounds it.
import std/io

tor bits { n: i64 } -> i64
bits -> @as(i64, @as(u6, @intCast(n)))

bits(n: 5): r |> std/io:print.ln("bits5: {{ r:d }}")
bits(n: 40): r |> std/io:print.ln("bits40: {{ r:d }}")
bits(n: 63): r |> std/io:print.ln("bits63: {{ r:d }}")

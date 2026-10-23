// Cross-target string equality: `==`/`!=` on strings is VALUE equality in
// Koru. The C lane must not leak the host's pointer compare — minted string
// bindings resolve to `const char *` through the binding registry, so the
// lowering spells `__koru_streq` (and `!__koru_streq`); the zig lane rewrites
// to optional-aware mem.eql; js `==` on primitives is already value equality.
// Every line must print identically on all three lanes.
import std/io

tor eq { a: string, b: string } -> i64
eq -> @intFromBool(a == b)

tor ne { a: string, b: string } -> i64
ne -> @intFromBool(a != b)

tor eqLit { a: string } -> i64
eqLit -> @intFromBool(a == "world")

eq(a: "same", b: "same"): r |> std/io:print.ln("eq_same={{ r:d }}")
eq(a: "same", b: "diff"): r |> std/io:print.ln("eq_diff={{ r:d }}")
ne(a: "same", b: "diff"): r |> std/io:print.ln("ne_diff={{ r:d }}")
ne(a: "same", b: "same"): r |> std/io:print.ln("ne_same={{ r:d }}")
eqLit(a: "world"): r |> std/io:print.ln("eq_lit_hit={{ r:d }}")
eqLit(a: "other"): r |> std/io:print.ln("eq_lit_miss={{ r:d }}")

// Cross-target `*X` pointer cells: `*X` lowers to a real C pointer on the
// c lane. A proto terminal's typedef already binds the name, so `*Tok`
// spells `Tok *` in declarations, parameters, fields, returns, bindings
// and call initializers — and `==` on pointer operands stays a pointer
// compare (the string-equality lowering only fires on `const char *`).
import std/io
import std/proto

std/proto:i64(Tok)

tor mk-tok { v: i64 } -> *Tok
proc mk-tok|zig { return @ptrFromInt(@as(usize, @intCast(v))); }
proc mk-tok|c { return (Tok *)v; }

tor same { a: *Tok, b: *Tok } -> i64
same -> @intFromBool(a == b)

tor touch { f: *Tok, tag: i64 } -> i64
touch -> tag + 1

mk-tok(v: 4096): x |> mk-tok(v: 8192): y |> same(a: x, b: y): r1 |> same(a: x, b: x): r2 |> mk-tok(v: 12288): f |> touch(f, tag: 41): r3 |> std/io:print.ln("ab={{ r1:d }} aa={{ r2:d }} touch={{ r3:d }}")

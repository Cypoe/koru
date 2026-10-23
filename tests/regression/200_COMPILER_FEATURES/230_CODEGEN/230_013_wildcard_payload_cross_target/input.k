// Pins `| hit *` wildcard payloads crossing the C lane: the decl's union
// member has no declared shape, so each lane mints a placeholder — zig
// `struct {}`, C `struct <ev>_<br>_t { char __koru_wildcard; }` — that
// compiles the tagged result while real value materialization still
// refuses (`=> hit v` is a type error on both lanes).
import std/io

tor pick { n: i64 }
| hit *
| miss

pick = if(n > 0)
| then => hit
| else => miss

pick(n: 1)
| hit _ |> std/io:print.ln("hit_a")
| miss |> std/io:print.ln("miss_a")

pick(n: -1)
| hit _ |> std/io:print.ln("hit_b")
| miss |> std/io:print.ln("miss_b")

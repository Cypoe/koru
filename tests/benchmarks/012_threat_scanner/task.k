// 012 — the X post's task shape: Where(score >= threshold)
//   .Select($"{ip} [{level}]").ToList()
// over sessions. One source, two backends: `koruc --lang=cs` races LINQ
// on .NET; `koruc` emits the same program native on zig.
//
// Sessions are derived from i — the producer is `for` + `! each`, pure .k,
// same discipline as the LINQ post's producers. `when` on `! each` is the
// Where, `cond` + `std/fmt:ln` the Select, `collect` the ToList.
import std/io
import std/fmt

pub tor level-name { l: i64 } -> string
pub tor collect { s: string }

pub tor run { n: i64, threshold: i64 }

level-name = cond(l)
| c l when l == 0 -> "Low"
| c l when l == 1 -> "Elevated"
| c l when l == 2 -> "High"
| c _ -> "Critical"

run = for(0..(@as(usize, @intCast(n))))
    ! each i when (@as(i64, @intCast(i)) * 31) % 100 >= threshold
        |> level-name(l: @as(i64, @intCast(i)) % 4): lvl
        |> std/fmt:fmt.blk {10.0.0.{{ i % 256:d }} [{{ lvl:s }}]}: s
        |> collect(s)

run(n: 10000000, threshold: 40) |> std/io:print.ln("hits={{ hits:d }} chars={{ chars:d }}")

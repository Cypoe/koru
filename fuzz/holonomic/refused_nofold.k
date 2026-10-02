import std/io

tor step { n: i64, acc: i64 }
| more { n: i64, acc: i64 }
| done i64

step = if(n < 8)
| then => more { n: n + 1, acc: acc + n }
| else => done acc

run = step(n: 1, acc: 0)
| more s |> s
| done e -> e

tor step { n: i64, acc: i64 }
| more { n: i64, acc: i64 }
| done i64

step = if(n < 12)
| then => more { n: n + 1, acc: acc * n }
| else => done acc

run = #L step(n: 1, acc: 1)
| more s |> @L(s.n, s.acc)
| done e -> e

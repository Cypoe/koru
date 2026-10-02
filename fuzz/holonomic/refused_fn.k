tor step { n: i64, acc: i64 }
| more { n: i64, acc: i64 }
| done i64

step = if(n < 8)
| then => more { n: n + 1, acc: @min(acc + n, 100) }
| else => done acc

run = #L step(n: 1, acc: 0)
| more s |> @L(s.n, s.acc)
| done e -> e

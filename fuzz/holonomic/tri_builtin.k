tor step { n: i64, acc: i64 }
| more { n: i64, acc: i64 }
| done i64

step = if(n < 20)
| then => more { n: n + 1, acc: acc + @divTrunc(n * (n + 1), 2) - @divTrunc((n - 1) * n, 2) }
| else => done acc

run = #L step(n: 1, acc: 0)
| more s |> @L(s.n, s.acc)
| done e -> e

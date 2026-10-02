tor step { n: i64, sq: i64 }
| more { n: i64, sq: i64 }
| done i64

step = if(n < 20)
| then => more { n: n + 1, sq: n * n }
| else => done sq

run = #L step(n: 1, sq: 0)
| more s |> @L(s.n, s.sq)
| done e -> e

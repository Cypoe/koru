// `when` on a non-continue arm — the exit selection carries a condition
// the model can't see (which `done` fires is state-dependent). Must
// refuse rather than certify a transition that isn't reached uniformly.
tor step { n: i64, acc: i64 }
| more { n: i64, acc: i64 }
| done i64

step = if(n < 20)
| then => more { n: n + 1, acc: acc + 2 * n - 1 }
| else when n > 100 => done acc
| else => done acc

run = #L step(n: 1, acc: 0)
| more s |> @L(s.n, s.acc)
| done e -> e

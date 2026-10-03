// Two record-producing continue arms under different `when` guards —
// the transition is conditional (F1 when n > 10, F2 otherwise), which
// is not one autonomous map. First-match extraction used to take
// whichever arm came textually first and certify THAT. Must refuse.
tor step { n: i64, acc: i64 }
| more { n: i64, acc: i64 }
| done i64

step = bump(n)
| ok _ when n > 10 => more { n: n + 1, acc: acc + n }
| ok _ => more { n: n + 2, acc: acc }
| boom _ => done acc

run = #L step(n: 0, acc: 0)
| more s |> @L(s.n, s.acc)
| done e -> e

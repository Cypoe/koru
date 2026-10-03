// sq_incr.k with the @L re-dispatch args swapped: the record still
// produces {n+1, acc+2n-1}, but the next state's n takes the acc field
// and vice versa — genuinely different dynamics. Pins that the gate
// composes the re-dispatch args into the transition instead of assuming
// an identity s->s map (pre-fix this gated EQUAL against sq_incr).
tor step { n: i64, acc: i64 }
| more { n: i64, acc: i64 }
| done i64

step = if(n < 20)
| then => more { n: n + 1, acc: acc + 2 * n - 1 }
| else => done acc

run = #L step(n: 1, acc: 0)
| more s |> @L(s.acc, s.n)
| done e -> e

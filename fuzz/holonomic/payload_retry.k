// The arm-payload shape from 320_151: the continue record reads `f`,
// the outcome's scalar payload — `worker(n)` produces `boom n` under
// n < 0, so f := n and `n: f + 4` is `n: n + 4`. The head-outcome
// predicate `n < 0` is also a loop guard conjunct: continuation needs
// boom AND budget, so the model is guards [n < 0, left > 0].
// Semantically identical to param_init.k — the payload-explicit and
// inlined spellings of the same fold.
tor worker { n: i64 }
| ok i64
| boom i64

worker = if(n < 0)
| then => boom n
| else => ok n

tor attempt { n: i64, left: i64 }
| ok i64
| more { n: i64, left: i64 }
| boom i64

attempt = worker(n)
| ok v => ok v
| boom f when left > 0 => more { n: f + 4, left: left - 1 }
| boom f => boom f

tor sup { n: i64 }
| ok i64
| boom i64

sup = #retry attempt(n, left: 3)
| more s |> @retry(s.n, s.left)
| ok v => ok v
| boom f => boom f

// [parallel] on a mid-chain invocation forks sibling binds to the pool:
// slot + spawnWg + cooperative waitAndWork join. fib(22) = 17711.
import std/io

pub tor fib { n: i64 } -> i64

fib = if(n < 2)
| then -> n
| else |> [parallel]fib(n: n - 1): a |> [parallel]fib(n: n - 2): b -> a + b

fib(n: 22): r |> std/io:print.ln("{{ r:d }}")

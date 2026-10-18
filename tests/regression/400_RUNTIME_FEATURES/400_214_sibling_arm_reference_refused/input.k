// PINS: KORU108 — one arm's binding is invisible to a SIBLING arm: `t` is
// bound by `| img t`, but the `| err` arm is a disjoint path through the
// dispatch, so `t` is not on its path either.
import std/io

pub tor load { n: i64 }
| img i64
| err i64

load = if(n < 0)
| then => err n
| else => img n

pub tor show { v: i64 }

show = std/io:print.ln("v {{ v:d }}")

load(n: 3)
| img t |> show(v: t)
| err e |> show(v: t)

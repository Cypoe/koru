// PINS: KORU108 — an arm binding referenced at the join after the arms is
// refused by the core flow checker. `t` is bound by `| img t`; the join
// (400_210) runs after whichever arm fired, so `t` is not on its path.
import std/io

pub tor load { n: i64 }
| img i64
| err i64

load = if(n < 0)
| then => err n
| else => img n

pub tor show { v: i64 }

show = std/io:print.ln("v {{ v:d }}")

std/io:print.ln("start")
    |> load(n: 3)
        | img t |> show(v: t)
        | err e |> show(v: e)
    |> show(v: t)

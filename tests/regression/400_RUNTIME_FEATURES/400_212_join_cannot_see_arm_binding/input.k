// PINS: an unnamed `|>` at a step's own level after that step's arms is the
// join (400_210), and arm bindings are arm-local — `t` bound by `| img t`
// is invisible at the join. `t` sits inside std/io's `{{ }}` interpolation,
// which the core flow checker does not read (KORU108 covers core call
// arguments only), so today the refusal is the host's `use of undeclared
// identifier 't'`.
import std/io

pub tor load { n: i64 }
| img i64
| err i64

load = if(n < 0)
| then => err n
| else => img n

std/io:print.ln("start")
    |> load(n: 3)
        | img t |> std/io:print.ln("img {{ t:d }}")
        | err e |> std/io:print.ln("err {{ e:d }}")
    |> std/io:print.ln("join {{ t:d }}")

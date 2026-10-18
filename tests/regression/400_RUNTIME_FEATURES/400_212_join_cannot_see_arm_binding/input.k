// PINS: an unnamed `|>` at a step's own level after that step's arms is the
// join (400_210), and arm bindings are arm-local — `t` bound by `| img t`
// is invisible at the join. No koruc-level unbound-reference check exists
// yet (same hole as 320_152): today the refusal is the host's
// `use of undeclared identifier 't'` from the emitted Zig.
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

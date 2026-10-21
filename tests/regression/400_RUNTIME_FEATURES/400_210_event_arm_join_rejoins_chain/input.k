// PINS: an unnamed `|>` at a step's own level after that step's arms is the
// JOIN for every tor, not only keyword tors (400_193 pins if, 400_205 for).
// Both arms of `load` fall into the join; arm bindings stay arm-local.
// Covers a top-level chain and a chain nested inside another tor's arm.
import std/io

pub tor load { n: i64 }
| img i64
| err i64

load = if(n < 0)
| then => err n
| else => img n

pub tor doit {}
| ok
| fail

doit => ok

std/io:print.ln("start")
    |> load(n: 3)
        | img t |> std/io:print.ln("img {{ t:d }}")
        | err e |> std/io:print.ln("err {{ e:d }}")
    |> std/io:print.ln("join 1")

doit()
| ok |> std/io:print.ln("mid")
    |> load(n: -2)
        | img t |> std/io:print.ln("img {{ t:d }}")
        | err e |> std/io:print.ln("err {{ e:d }}")
    |> std/io:print.ln("join 2")
| fail |> _

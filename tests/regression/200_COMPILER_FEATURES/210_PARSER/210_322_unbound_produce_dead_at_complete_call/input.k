// PINS: a `|>` produce with no name that reaches a step whose parameters are
// ALL written is computed and dropped — the conveyor loses its cargo with no
// refusal and no way to ever reference the value. The thread's no-destination
// refusal must fire here exactly as it fires for a type mismatch (210_181):
// zero open slots is zero candidates.
//
// The deliberately-spelled escapes stay legal: bind the produce and write it
// (`produce(): s |> f(a: s)` — 210_323), or drop it at the source (`:_`).
import std/io

tor other {} -> string
proc other|zig { return "other"; }

tor produce {} -> string
proc produce|zig { return "made"; }

tor consume { a: string } -> string
proc consume|zig { return a; }

other(): o |> produce() |> consume(a: o): r
    |> std/io:print.ln("{{ r:s }}")

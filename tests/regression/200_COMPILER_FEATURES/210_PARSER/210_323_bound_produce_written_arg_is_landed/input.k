// PINS: a bound produce written into a slot by name IS the thread landing —
// `produce(): s |> consume(a: s)` spells the fill the point-free form would
// elect. Complete calls are legal when the produce's name is among the
// written args: the value arrived, the author said where.
//
// Sibling of 210_322 — the refusal there is for the value nobody named and
// nothing can reach, not for the call the author completed by hand.
import std/io

tor produce {} -> string
proc produce|zig { return "made"; }

tor consume { a: string } -> string
proc consume|zig { return a; }

produce(): s |> consume(a: s): r |> std/io:print.ln("{{ r:s }}")

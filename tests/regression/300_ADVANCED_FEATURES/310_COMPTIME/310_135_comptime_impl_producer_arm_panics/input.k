// Pins that a [comptime] subflow impl produces its tor's result through a
// `=>` arm — the walker's decorative-arm semantics (310_091 pins named arms
// on bare returns working at comptime) make `| ok v => result v` the
// spelling for a comptime tor implemented by a subflow returning a value.
//
// The defect this guards: fold treated the impl body as fold residue — it
// evaluated the head, then promoted the matched `=>` arm to the flow root,
// leaving a flow whose head node was a branch_constructor. Every later
// flow.inv() site asserts the head is an invocation — backend SIGABRT, no
// diagnostic. Fold now leaves impl bodies to the walker, which owns them.
// (Without [comptime], a named arm on a bare return is KORU021 — a refusal
// the comptime path intentionally does not inherit.)

import std/io

[comptime] pub tor lit {} -> string
[comptime] lit -> "x"

[comptime] pub tor get-input {} -> string

[comptime] get-input = lit()
| ok v => result v

[comptime] get-input(): s |> std/io:print.ln(s)

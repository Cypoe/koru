// PINS: in a `|>` step, the previous stage's `-> T` is the NEAREST binding of
// its type — nearer than any bind already in scope — because `|>` is the
// conveyor: the value that just arrived is the one the step should see.
//
// `o` is in scope, live (the last step reads it), and `string`-compatible
// with `a` — so a fill pass that runs before the thread elects claims `a` for
// `o` and the produce is computed and silently discarded (the defect this
// test guards). The thread wins its own step: "a=made", never "a=other".
//
// Sibling of 210_321 (several candidates stay KORU093 even when a compatible
// binding is in scope) and child of 210_176 (WHERE the thread lands). This
// one pins THAT the thread lands at all when scope could have answered.
import std/io

tor other {} -> string
proc other|zig { return "other"; }

tor produce {} -> string
proc produce|zig { return "made"; }

tor consume { a: string, b: string } -> string
proc consume|zig { return a; }

other(): o |> produce() |> consume(b: "B"): r
    |> std/io:print.ln("a={{ r:s }}")
    |> std/io:print.ln("o={{ o:s }}")

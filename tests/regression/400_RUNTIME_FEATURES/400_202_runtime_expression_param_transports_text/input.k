// PIN — `expr: Expression` on a runtime tor transports the captured source
// text to a plain |zig proc as `[]const u8`. The field is another way to pass
// a string — captured, not evaluated — so the proc receives `2 + 3`, not 5.
// Comptime consumption (`[expand]`/`[template]` splicing) is pinned in
// 400_184/400_187; this pins the runtime boundary.
import std/io

tor calc { expr: Expression } -> string
proc calc|zig {
    return expr;
}

calc(expr: 2 + 3): r |> std/io:print.ln("{{ r:s }}")

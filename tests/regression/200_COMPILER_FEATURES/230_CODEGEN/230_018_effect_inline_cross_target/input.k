// A `!`-declaring event lowers per call site on the c lane: the proc's |c
// body inlines at the invocation and `__koru_raise_item(v)` splices the
// consumer's `! item` arm — the same lowering the zig lane performs with
// its comptime __H handlers. `| done` still dispatches through the tagged
// result; `return` in the |c body retargets to the call's result cell.
import std/io

pub tor each-i32 { items: []const i32 }
! item i32
| done usize

each-i32(items: &[_]i32{ 10, 20, 30 })
! item v |> std/io:print.ln("saw {{ v:d }}")
| done n |> std/io:print.ln("done {{ n:d }}")

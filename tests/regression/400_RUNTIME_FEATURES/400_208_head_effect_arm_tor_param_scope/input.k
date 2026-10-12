// PINS: a `!` arm at an impl flow's head cannot see the implementing
// tor's params — KORU207 refuses at check time, before any Zig exists.
//
// Sibling of 400_175/400_200/400_207 (the head-arm partition cluster). An
// impl flow whose head invokes an effectful proc/tor lowers each `!` arm
// into a synthesized `Handlers_sf` struct passed `comptime` to the call —
// a context-free fn that sees module scope only. A reference to a tor
// param used to survive shape checking and die in emitted Zig:
//
//     error: 'tag' not accessible from inner function
//
// Mid-chain `!` arms inline and keep the enclosing frame (not the wall);
// `[template]` procs (for/if/capture) substitute at the head and are also
// exempt. The wall is exactly: impl-flow head + real effectful decl.
import std/io
import std/string

tor render { t: string, tag: string }
render = std/string:split(s: t, sep: "|")
! piece p |> std/io:print.ln(tag) |> std/io:print.ln(p)
| done _ |> _

render(t: "a|b", tag: "x:")

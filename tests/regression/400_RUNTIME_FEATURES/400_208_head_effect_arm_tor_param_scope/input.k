// PINS: a `!` arm at an impl flow's head sees the implementing tor's
// params — they ride the `__HandlersCaps_*` capture record, instantiated
// and assigned at the call site where the params are live.
//
// Sibling of 400_175/400_200/400_207 (the head-arm partition cluster). An
// impl flow whose head invokes an effectful proc/tor lowers each `!` arm
// into a synthesized `Handlers_sf` struct passed `comptime` to the call —
// a context-free fn. Enclosing-scope names the arm references but does
// not bind become container vars of the `__HandlersCaps_*` factory's
// instantiated struct; the member fn rebinds them in a prelude const, so
// `tag` below is the tor's own param, not a stale name.
import std/io
import std/string

tor render { t: string, tag: string }
render = std/string:split(s: t, sep: "|")
! piece p |> std/io:print.ln(tag) |> std/io:print.ln(p)
| done _ |> _

render(t: "a|b", tag: "x:")

// TEST: fmt:ln scratch-borrow lifetime — pins the documented hazard, not a
// desired end state.
//
// Every fmt:ln call site emits its own threadlocal 4KiB scratch and `.text`
// borrows it, so `a` and `b` below are two names over ONE buffer. The second
// render overwrites the first: the honest output is "item 2 / item 2", where
// the naive reading expects "item 1 / item 2". That is the contract as it
// exists — consume `.text` in place, never let it outlive its site's next
// execution.
//
// This pin exists so the fix has a witness: when `.text` carries a scratch
// obligation (intended: refused on produce into a longer-lived value, the
// way `string<unsanitized!>` refuses a taint sink — 330_069), this program
// must STOP compiling, and this file becomes a MUST_ERROR pin instead.
// See the lifetime contract in koru_std/fmt.kz above `pub tor ln`.

import std/fmt
import std/io

tor render { n: i64 } -> string

render = std/fmt:ln("item {{ n:d }}"): l -> l.text

render(n: 1): a |> render(n: 2): b |> std/io:print.ln(a) |> std/io:print.ln(b)

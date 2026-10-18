// 690_365 — a store subscript whose index is PROVABLY not a row handle is
// refused at compile time (KORU161), not left to the runtime brand panic.
//
// res[world.focus] indexes res with a SCALAR store's column read. A scalar
// column can never carry a res row handle — handles are minted by `| row`,
// row cursors, or a handle-carrying column of the SAME store (the self-FK
// shape, `nodes[a.next]`, is sanctioned and stays legal — 690_048 is the
// control). world.focus is provably not any of those, so this program must
// be refused; today it compiles and panics in __koru_resolve at runtime.
//
// Shape surfaced by koru-libs/metal: drift.k/tilt.k keyed touch on
// res[world.focus]; the first real keypress panicked with 'does not
// address a row'. The fix on the consumer side is the guarded sweep
// (! query r when r.id == world.focus); this pin covers the refusal.

import std/store
import std/io

std/store:new(world) { focus: 0[i64] }
std/store:new(res, capacity: 8) { id: i64, touched: i64 }

std/store:insert(res) { id: 0, touched: 0 }
| row _ |> std/store:stored { res[world.focus].touched: 1 }

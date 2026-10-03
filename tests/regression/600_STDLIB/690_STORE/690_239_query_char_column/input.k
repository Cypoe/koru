// 690_239 — a char[N] column read through `query`, the read-now verb.
//
// Pins the query-side char projection: `query e` binds `e.label` as the row
// text up to the first NUL (sliceTo over the [N]u8 cell), not the raw array —
// the body's Input types the field []const u8, so a plain indexed read does
// not coerce. 690_052 covers the same store on `rule`; this is the query verb
// over identical rows. The cell carries char-ness only in the SoA column
// type — the synthesized insert event spells it []const u8, indistinguishable
// from a slice field — so the projection re-derives it from the store's own
// declaration (charCap), not from the column's binding type. Same store, same
// rows, same expected output as 690_052; only the verb differs.
import std/io
import std/store

std/store:new(todos, capacity: 8) { done: i64, label: char[16] }

std/store:insert(todos) { done: 0, label: "buy milk" }
| row _ |> std/store:insert(todos) { done: 1, label: "ship koru" }
    | row _ |> _

std/store:query(todos)
! query e |> std/io:print.ln("[{{ e.done:d }}] {{ e.label:s }}")

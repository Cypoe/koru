// 690_368 — a `stored` value expression inside a `query` sweep reads a
// char[N] column.
//
// Pins the `.live` lowering (SRewrite.refs, store.qrewrite.kz): a stored
// RHS reads the row as it is NOW at the dense cursor, and a char[N] cell
// read there must bind the row text up to the first NUL — the same
// projection the qrow input carries (`__koru_srf_*`, store.hostemit's
// cellRead). The write path's PRewrite.colRead already spelled it; the
// read side's .live is the third surface the contract must reach.
// A raw `[N]u8` cell read cannot feed `== "…"` — mem.eql wants slices —
// nor a []const u8 parameter.
//
// 690_239 pins the same projection on the `.input` side; this is the
// `.live` twin. The else-branch read (`e.done`) covers scalar .live
// unchanged.
import std/io
import std/store

std/store:new(todos, capacity: 8) { done: i64, label: char[16] }

std/store:insert(todos) { done: 0, label: "buy milk" }
| row _ |> std/store:insert(todos) { done: 1, label: "ship koru" }
    | row _ |> _

std/store:query(todos)
! query e |> std/store:stored { todos[e].done: if (e.label == "buy milk") 9 else e.done }

std/store:query(todos)
! query e |> std/io:print.ln("[{{ e.done:d }}] {{ e.label:s }}")

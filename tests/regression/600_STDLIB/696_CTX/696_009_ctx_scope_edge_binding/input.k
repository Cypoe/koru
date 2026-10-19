// 696_009 — the edge feeding a ctx step carries real payload: `| row r`
// binds the insert's row handle, and when the ctx step splices itself out
// the binding must land on the promoted kid. Without the transfer the
// scope expression `outer[r]` reads a binding that never emitted.
import std/io
import std/store
import std/ctx

std/store:new(outer, capacity: 8) { a: i64, b: i64, c: i64 }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

std/store:insert(outer) { a: 1, b: 2, c: 3 }
| row r |> std/ctx(outer[r]) |> ctxprobe()

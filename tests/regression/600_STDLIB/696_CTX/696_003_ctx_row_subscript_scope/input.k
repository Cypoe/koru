// 696_003 — std/ctx scope value as a row subscript: `std/ctx(outer[r])`
// reads the scope's SCHEMA off the base store (`outer`) while the injected
// argument keeps the full expression — each call site emits a row-subscript
// read `outer[r].field` that resolves `r` at run. Two rows, two scopes,
// same tor: the handle chooses which row supplies the subtree's params.

import std/io
import std/store
import std/ctx

std/store:new(outer, capacity: 8) { a: i64, b: i64, c: i64 }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

std/store:insert(outer) { a: 1, b: 2, c: 3 }
| row r0 |> std/store:insert(outer) { a: 10, b: 20, c: 30 }
    | row r1 |> std/io:print.ln("seed")
        |> std/ctx(outer[r0]) |> ctxprobe()
        |> std/ctx(outer[r1]) |> ctxprobe()

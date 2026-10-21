// 696_010 — a ctx scope resolves its schema regardless of source order:
// the flow names `late` before its `store:new` site appears. Scope
// resolution is a consumer of produced decls, and consumers run after
// producers — the transform stage boundary, not file position, decides
// visibility. The injected reads happen before the insert in program
// order, so the store's zero-init values are what print.
import std/io
import std/store
import std/ctx

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

std/io:print.ln("seed")
|> std/ctx(late) |> ctxprobe()

std/store:new(late) { a: i64, b: i64, c: i64 }
|> std/store:insert(late) { a: 1, b: 2, c: 3 }

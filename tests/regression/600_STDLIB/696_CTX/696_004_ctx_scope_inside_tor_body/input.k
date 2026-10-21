// 696_004 — std/ctx inside a tor's own body: the scope is lexical, so a
// `ctx` step in an impl body injects there exactly as at flow top level.
// A nullary tor wrapping a scoped chain is also the partial-application
// spelling: `local` is a callable that captured a context, invocable
// from anywhere.

import std/io
import std/store
import std/ctx

std/store:new(inner) { a: 9[i64], b: 8[i64], c: 7[i64] }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

pub tor local { }
local = std/ctx(inner) |> ctxprobe()

std/io:print.ln("seed")
|> local()

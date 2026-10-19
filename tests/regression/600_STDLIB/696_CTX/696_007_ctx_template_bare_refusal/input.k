// 696_007 — a callee cloned under a ctx scope is a template: its original
// impl is consumed by specialization and its decl is marked [abstract], so
// a bare call to it in a sibling flow (outside any scope) refuses under
// KORU047 rather than silently stubbing to a no-op.

import std/io
import std/store
import std/ctx

std/store:new(inner) { a: 9[i64], b: 8[i64], c: 7[i64] }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

pub tor needs-scope { }
needs-scope = ctxprobe()

std/io:print.ln("seed")
|> std/ctx(inner) |> needs-scope()

std/io:print.ln("bare")
|> needs-scope()

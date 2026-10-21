// 696_001 — std/ctx: lexical scope injection via the bare-attach default tor.
//
// PINS the scope-stack semantics: `std/ctx(X)` is a compile-time scope over
// its continuation subtree; every invocation inside gets unfilled params
// injected from the nearest enclosing scope whose named store provides a
// field of that name.
//   explicit arg > innermost ctx > outward ctx > declared default > refusal
// The ctx step splices out at comptime — the emitted call reads store cells
// directly; nothing resolves at run. ctxprobe is a probe tor declared in
// this file that prints the params it received; the feature under test is
// the injection, not the probe.

import std/io
import std/store
import std/ctx

std/store:new(outer) { a: 1[i64], b: 2[i64], c: 3[i64] }
std/store:new(inner) { a: 9[i64] }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

std/io:print.ln("seed")
|> std/ctx(outer) |> ctxprobe()
|> std/ctx(inner) |> ctxprobe()
|> ctxprobe(b: 42)

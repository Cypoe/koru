// 696_002 — std/ctx: a param no enclosing scope provides refuses through the
// ordinary missing-input diagnostic — injection adds no new error path.
//
// PINS the tail of the precedence chain: explicit arg > innermost ctx >
// outward ctx > declared default > ordinary missing-param refusal. ctx(inner)
// provides `a` only; `b` and `c` are required (no default, no `?`), so the
// shape checker refuses them exactly as it would without any ctx.

import std/io
import std/store
import std/ctx

std/store:new(inner) { a: 9[i64] }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("unreached")

std/io:print.ln("seed")
|> std/ctx(inner) |> ctxprobe()

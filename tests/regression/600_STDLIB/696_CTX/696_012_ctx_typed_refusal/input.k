// 696_012 — std/ctx: a name present only with a misfitting type does not
// inject. inner.a is f64; the callee wants a: i64 and no scope provides a
// compatible `a`.
//
// PINS the refusal tail of typed matching: the mistyped column is skipped
// (not injected, not coerced), the param stays unfilled, and the call
// refuses through the ordinary missing-input path — ctx adds no new
// error path.

import std/io
import std/store
import std/ctx

std/store:new(inner) { a: 1.5[f64] }

pub tor want-int { a: i64 }
want-int = std/io:print.ln("unreached")

std/io:print.ln("seed")
|> std/ctx(inner) |> want-int()

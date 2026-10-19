// 696_005 — std/ctx scope crosses the subflow boundary by keyed clone
// specialization: `needs-scope`'s body calls `ctxprobe()` unfilled, so the
// callee consumes the scope; the call under `std/ctx(inner)` is dispatched
// to a synthesized `needs-scope__ctx_inner` whose body's call is injected
// from the scope. The original impl is a template — it carries no
// emission of its own once specialized.

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

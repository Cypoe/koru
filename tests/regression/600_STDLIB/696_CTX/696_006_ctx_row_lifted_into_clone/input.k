// 696_006 — a row-subscript scope crossing a subflow boundary lifts its
// binding into the clone's input: `std/ctx(themes[r]) |> consume-scope()`
// dispatches to `consume-scope__ctx_themesIDX(__ctxarg0: r)` — the clone's
// body reads `themes[__ctxarg0].field`. Call sites with different bindings
// (r0, r1) share the ONE specialization; the handle arrives as a param.

import std/io
import std/store
import std/ctx

std/store:new(themes, capacity: 8) { a: i64, b: i64, c: i64 }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

pub tor consume-scope { }
consume-scope = ctxprobe()

std/store:insert(themes) { a: 1, b: 2, c: 3 }
| row r0 |> std/store:insert(themes) { a: 10, b: 20, c: 30 }
    | row r1 |> std/io:print.ln("seed")
        |> std/ctx(themes[r0]) |> consume-scope()
        |> std/ctx(themes[r1]) |> consume-scope()

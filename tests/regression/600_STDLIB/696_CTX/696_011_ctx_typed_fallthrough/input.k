// 696_011 — std/ctx: matching is name + exact canonical type, not name
// alone. inner.a is f64; outer.a is i64.
//
// PINS typed scope selection: a same-named column whose type cannot serve
// the callee's param does NOT shadow — it falls through to outer scopes.
// want-int gets `a` from outer (past mistyped inner.a), want-float gets
// `a` from inner (innermost compatible). The same stack answers the same
// name differently per callee signature.
//
//   precedence: explicit arg > innermost compatible ctx > outward ctx >
//   declared default > refusal

import std/io
import std/store
import std/ctx

std/store:new(outer) { a: 7[i64], b: 8[i64] }
std/store:new(inner) { a: 1.5[f64] }

pub tor want-int { a: i64, b: i64 }
want-int = std/io:print.ln("want-int a={{ a:d }} b={{ b:d }}")

pub tor want-float { a: f64 }
want-float = std/io:print.ln("want-float a={{ a:f }}")

std/io:print.ln("seed")
|> std/ctx(outer) |> std/ctx(inner) |> want-int()
|> want-float()

// 696_005 — std/ctx is lexical, not transitive: a scope at the call site
// does NOT reach inside the callee's own body. needs-scope's inner
// ctxprobe() call is lexically outside the ctx subtree, so all three
// required params stay unfilled and the ordinary arity check refuses.
// Transitive reach is the keyed-subflow specialization — a separate,
// still-open design; until then this refusal IS the contract.

import std/io
import std/store
import std/ctx

std/store:new(inner) { a: 9[i64], b: 8[i64], c: 7[i64] }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("unreached")

pub tor needs-scope { }
needs-scope = ctxprobe()

std/io:print.ln("seed")
|> std/ctx(inner) |> needs-scope()

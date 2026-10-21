// 696_008 — a recursive tor under a ctx scope: the clone's recursive call
// hits the SAME specialization key, so `countdown__ctx_inner` dispatches
// to itself — specialization terminates instead of generating clones
// forever.

import std/io
import std/store
import std/ctx

std/store:new(inner) { a: 9[i64] }

pub tor ctxprobe { a: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }}")

pub tor countdown { n: i64 }
countdown = if(n == 0)
| then |> std/io:print.ln("done")
| else |> ctxprobe() |> countdown(n: n - 1)

std/io:print.ln("seed")
|> std/ctx(inner) |> countdown(n: 2)

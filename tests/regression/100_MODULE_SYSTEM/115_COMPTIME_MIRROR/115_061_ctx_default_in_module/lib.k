import std/io
import std/store
import std/ctx

std/store:new(outer) { a: 1[i64], b: 2[i64], c: 3[i64] }

pub tor ctxprobe { a: i64, b: i64, c: i64 }
ctxprobe = std/io:print.ln("ctxprobe a={{ a:d }} b={{ b:d }} c={{ c:d }}")

pub tor run {}

run = std/io:print.ln("seed")
|> std/ctx(outer) |> ctxprobe()
|> ctxprobe(b: 42)

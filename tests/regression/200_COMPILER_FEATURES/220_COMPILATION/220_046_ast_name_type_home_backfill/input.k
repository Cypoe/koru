import app/lib
import std/io

pub tor drop-item { i: *app/lib:Item<!app/lib:live> }

app/lib:thing.make(): i
|> std/io:print.ln("ok")

// lib.k — `std/json:parse` declared and used from an imported module. The
// transform compiles a bespoke recursive-descent parser per call site; this
// is the position that tells a correct emitted unit qualifier from a lucky
// one — the entry file collapses file-name and module-name into one word,
// so 642_001 cannot see a qualifier that lands wrong.
import std/io
import std/json

pub tor greet { body: string }
greet = std/json:parse(input: body)
| malformed { message, offset } |> std/io:print.ln("mod BAD {{ offset:d }}: {{ message:s }}")
| ok { name: string, age: i64, tags: []string } |> std/io:print.ln("mod {{ name:s }}|{{ age:d }}|{{ tags.len:d }}")

pub tor scan { body: string }
scan = std/json:parse(input: body)
| malformed { message, offset } |> std/io:print.ln("mod invalid {{ offset:d }}: {{ message:s }}")
| ok s |> std/io:print.ln("mod valid {{ s:s }}")

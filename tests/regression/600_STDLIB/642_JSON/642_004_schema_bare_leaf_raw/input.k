// Test: a bare schema leaf carries the value's raw JSON span. Where
// `name: string` decodes, a bare `payload` in the destructure binds the
// uninterpreted `[]const u8` slice (quotes included on strings) — the .raw
// arm of the schema emitter (__rst<d> + __jskip). Witness for the __rst{}
// emit variant (variant-coverage).

import std/io
import std/json

std/json:parse(input: "{\"id\":42,\"payload\":{\"nested\":[1,2,3]}}")
| malformed { message, offset } |> std/io:print.ln("BAD {{ offset:d }}: {{ message:s }}")
| ok _:{ id: i64, payload } |> std/io:print.ln("id={{ id:d }} payload={{ payload:s }}")

std/json:parse(input: "{\"id\":7,\"payload\":\"a string\"}")
| malformed { message, offset } |> std/io:print.ln("BAD2 {{ offset:d }}: {{ message:s }}")
| ok _:{ id: i64, payload } |> std/io:print.ln("id={{ id:d }} payload={{ payload:s }}")

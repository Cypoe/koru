// Pins std/json:parse — schema-directed compile-time JSON parsing. The `ok`
// branch's destructure is the schema: leaf `string`/`i64`/`f64`/`bool`
// convert at the splice, `{...}` is a nested object shape, `?T` admits a
// missing key or literal null, `[]T` is an elementwise-decoded array.
// Undeclared keys are skipped (fully validated, not balance-checked —
// `{"a":}` must route to malformed), duplicate keys last-wins, required
// fields missing is a parse failure, and `| malformed` gets
// {message, offset}. A destructure-less `| ok s` is recognizer mode: the
// binding carries the consumed span. Field values are arena-scoped to the
// branch's chain — scoped borrow, not caller-owned.

import std/io
import std/json

// nested object + optional + array + unknown keys + escapes
std/json:parse(input: "{\"name\":\"ada\\nlovelace\",\"age\":36,\"addr\":{\"city\":\"paris\",\"zip\":\"75001\"},\"tags\":[\"a\",\"b\",\"c\"],\"nick\":null,\"extra\":{\"deep\":[1,{\"x\":2}]},\"junk\":[true,false,null,1.5e2]}")
| malformed { message, offset } |> std/io:print.ln("BAD {{ offset:d }}: {{ message:s }}")
| ok _:{ name: string, age: i64, addr: { city: string }, tags: []string, nick: ?string } |> if(nick == null)
    | then |> std/io:print.ln("{{ name:s }}|{{ age:d }}|{{ city:s }}|nick=null|tags={{ tags.len:d }}")
    | else |> std/io:print.ln("FAIL-nick")

// missing optional field
std/json:parse(input: "{\"name\":\"bob\",\"age\":7,\"addr\":{\"city\":\"lyon\"},\"tags\":[]}")
| malformed { message, offset } |> std/io:print.ln("BAD2 {{ offset:d }}: {{ message:s }}")
| ok _:{ name: string, age: i64, addr: { city: string }, tags: []string, nick: ?string } |> if(nick == null)
    | then |> std/io:print.ln("{{ name:s }} {{ age:d }} {{ city:s }} nick=null tags={{ tags.len:d }}")
    | else |> std/io:print.ln("FAIL2-nick")

// optional present
std/json:parse(input: "{\"name\":\"cid\",\"age\":9,\"addr\":{\"city\":\"oslo\"},\"tags\":[\"x\"],\"nick\":\"ciddy\"}")
| malformed { message, offset } |> std/io:print.ln("BAD3 {{ offset:d }}: {{ message:s }}")
| ok _:{ name: string, age: i64, addr: { city: string }, tags: []string, nick: ?string } |> if(nick == "ciddy")
    | then |> std/io:print.ln("{{ name:s }} {{ age:d }} {{ city:s }} nick=present tags={{ tags.len:d }}")
    | else |> std/io:print.ln("FAIL3-nick")

// malformed input
std/json:parse(input: "{\"name\":\"unterminated")
| malformed { message, offset } |> std/io:print.ln("BAD4 {{ offset:d }}: {{ message:s }}")
| ok _:{ name: string, age: i64 } |> std/io:print.ln("FAIL4 {{ name:s }}{{ age:d }}")

// missing required field
std/json:parse(input: "{\"name\":\"zed\"}")
| malformed { message, offset } |> std/io:print.ln("BAD5 {{ offset:d }}: {{ message:s }}")
| ok _:{ name: string, age: i64 } |> std/io:print.ln("FAIL5 {{ name:s }} {{ age:d }}")

// recognizer mode — no destructure
std/json:parse(input: "[1,{\"a\":true},null,\"x\"]")
| malformed { message, offset } |> std/io:print.ln("BAD6 {{ offset:d }}: {{ message:s }}")
| ok s |> std/io:print.ln("valid {{ s:s }}")

std/json:parse(input: "{\"a\":}")
| malformed { message, offset } |> std/io:print.ln("BAD7 {{ offset:d }}: {{ message:s }}")
| ok s |> std/io:print.ln("FAIL7 {{ s:s }}")

// floats + bools + duplicate keys (last wins)
std/json:parse(input: "{\"flag\":true,\"pi\":3.25,\"v\":1,\"v\":2}")
| malformed { message, offset } |> std/io:print.ln("BAD8 {{ offset:d }}: {{ message:s }}")
| ok _:{ flag: bool, pi: f64, v: i64 } |> std/io:print.ln("flag={{ flag:any }} pi={{ pi:f }} v={{ v:d }}")

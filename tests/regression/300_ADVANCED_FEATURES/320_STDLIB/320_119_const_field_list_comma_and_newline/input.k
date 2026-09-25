// PINS: the legal `const { }` field list — `name: value` entries separated by
// commas, by newlines, or mixed, with optional `[type]` annotations and a
// trailing comma — compiles and runs. Sibling of the malformed-entry refusals:
// the field-list rules refuse bad entries, never a legal list.
import std/io

const {
    a: @as(i32, 5), b: @as(i32, 2),
    c: 10[i32]
    d: "ok",
}

std/io:print.ln("{{ a + b + c:d }} {{ d:s }}")

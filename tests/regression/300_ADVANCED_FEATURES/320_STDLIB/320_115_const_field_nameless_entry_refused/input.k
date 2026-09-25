// PINS: a `const { }` entry with no name — `: @as(i32, 2)` — is refused
// KORU176, not silently dropped from the emitted declarations. The caret
// lands on the line carrying the nameless entry.
import std/io

const {
    a: @as(i32, 5), : @as(i32, 2)
}

std/io:print.ln("unreachable")

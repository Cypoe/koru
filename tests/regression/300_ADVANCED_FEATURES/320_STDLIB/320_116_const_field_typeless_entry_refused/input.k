// PINS: a `const { }` entry with no value — `b:` — is refused KORU176, not
// emitted as `const b = ;` for the Zig backend to reject. The caret lands on
// the line carrying the valueless entry.
import std/io

const {
    a: @as(i32, 5), b:
}

std/io:print.ln("unreachable")

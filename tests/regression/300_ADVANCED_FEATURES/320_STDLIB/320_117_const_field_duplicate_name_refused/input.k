// PINS: a `const { }` field list takes each name once — a second `a:` is
// refused KORU176 naming the twice-bound name, not emitted as a duplicate
// `const` member for the Zig backend to reject.
import std/io

const {
    a: @as(i32, 5), a: @as(i32, 2)
}

std/io:print.ln("unreachable")

// PINS: a comma-less multi-line store field list is refused with a diagnostic
// that names the missing comma — not a fused-column type error. Without the
// trailing comma, the field splitter reads `label`'s type as
// `*std/string:String<std/string:instance!>\ndone: i64` — two fields fused
// into one type string — and the refusal used to report that whole string as
// the column type, leaving the author to debug a type error that is really a
// punctuation error.

import std/io
import std/string
import std/store

std/store:new(tasks, capacity: 8) {
    label: *std/string:String<std/string:instance!>
    done: i64
}

std/io:print.ln("unreachable")

// PINS: a comma in a foreign field list refuses — bare names separate on
// lines; the comma is a wart, not a separator.
import std/foreign

std/foreign:struct(File) {
    path,
    handle
}

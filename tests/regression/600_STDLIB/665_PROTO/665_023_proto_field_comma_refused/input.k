// PINS: a comma in a proto field list refuses — entries separate on lines;
// the comma is a wart, not a separator (ruled in the entry-grammar frag).
import std/proto

std/proto(Point) {
    x: i64,
    y: i64
}

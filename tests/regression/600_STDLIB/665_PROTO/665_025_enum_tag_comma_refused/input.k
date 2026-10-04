// PINS: a comma in an enum tag list refuses — tags separate on lines;
// the comma is a wart, not a separator.
import std/types

std/types:enum(ThreatLevel) {
    low,
    high
}

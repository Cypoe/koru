// PINS: a closed tag set cannot repeat a member — a duplicate tag is a
// Koru-layer refusal naming the tag.
import std/types

std/types:enum(ThreatLevel) {
    low
    medium
    low
}

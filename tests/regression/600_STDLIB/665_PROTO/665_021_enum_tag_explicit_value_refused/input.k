// PINS: an enum tag carrying an explicit value (`low: 5`) is a Koru-layer
// refusal, not a half-parse — rung 1 mints implicit i64 ordinals only.
import std/types

std/types:enum(ThreatLevel) {
    low: 5,
    high
}

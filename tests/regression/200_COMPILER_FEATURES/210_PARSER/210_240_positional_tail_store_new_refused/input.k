// PINS: a call's first parameter is the positional `expr: Expression`
// subject; every argument after it must be `name: expr` — or a bare
// identifier, which puns. A bare literal in position >=2 cannot pun and
// must refuse. Measured 2026-09-24: `std/store:new(game, 37)` compiled and
// silently dropped the 37 — the transform only reads args with
// `had_explicit_label`, so the capacity fell back to default unreported.
// Aspirational red: the law is enforced for `captured {}` (320_136) but
// never reached call-arg lists.
import std/store

std/store:new(game, 37) { hp: i64 }

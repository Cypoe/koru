// PINS: same law, different construct head — `std/pump:create(main, 5)`
// carries a bare literal tail that cannot pun. Measured 2026-09-24:
// compiles, the 5 silently dropped.
import std/pump

std/pump:create(main, 5)

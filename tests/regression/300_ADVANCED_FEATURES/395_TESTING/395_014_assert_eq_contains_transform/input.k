// Pins: multi-Expression transform handlers fire inside test blocks.
//
// `assert.eq`/`assert.contains` declare two Expression params — the
// transform-runner's call site must extract each by name (positional
// fallback), qualify the multi-segment keyword path, and replace the
// invocation with the emitted inline check. If any of those steps miss,
// the invocation survives to emission as a raw `.handler(.{ ... })` call
// with arg-text field names.

import std/testing
import std/io

test(eq positional args) {
    assert.eq(1, 1)
    |> assert.ok()
}

test(eq named args) {
    assert.eq(expected: 2, actual: 2)
    |> assert.ok()
}

test(contains fires) {
    assert.contains("hello world", "wor")
    |> assert.ok()
}

// Run-flow surface: the same transforms fire outside test blocks —
// a passing assert.eq is silent, the print proves the flow continued.
assert.eq(expected: 3, actual: 3)
std/io:print.ln("run-flow asserts passed")

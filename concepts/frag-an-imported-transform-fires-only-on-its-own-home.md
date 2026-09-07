---
type: belief
id: frag-an-imported-transform-fires-only-on-its-own-home
provenance: 667/810_142 session 2026-09-07 — list:free was rewriting map:free because transform tors stayed on legacy bare-segment match
ts: 2026-09-07
tags: [koru, transforms, dispatch, module-qualifier]
---

# An imported transform fires only on its own home (belief)

A transform that lives in an imported module matches an invocation only when
that invocation spells the transform's module. Same bare event name in a
sibling module is a different event. Two exceptions stay bare-segment:
globs (taps capture user events by design) and `[keyword]` transforms
(the user spelling IS the bare name — `assert`, not `std.testing:assert`).

The keyword exception is not a courtesy. The `test` transform re-runs the
body through `run_pass` without keyword-resolution, so an `assert` inside
`test` still carries the test module's qualifier. Qualifying `std.testing:assert`
made that inner pass miss, and the body emitted a call to a missing
`assert_event` (395_001 / the 395 cluster that went red on the first board
of this ruling).

This is the same soundness the `[transform]proc` path already had (qualified-only,
never a bare capture). Transform *tors* were left on the legacy gate: match
the segment, ignore the home. That is not a convenience. It is a capture.
`std/list:free` rewrote `std/map:free` onto a list trunk name that map does
not own. The program that wrote the real spelling was innocent.

The fork in [[frag-two-mechanisms-mark-a-transform]] is why the hole lasted:
the two mechanisms disagreed about marking, and they also disagreed about
dispatch. The proc half was the one that did not steal. Closing the dispatch
half does not settle the marking fork.

What would `correct` this: a ruling that a library transform may rewrite
every module's same-named event on purpose — a global `free` / `get` / `new`
as one compiler pass. Until that ruling, a cross-module fire is a defect.

Pins: `660_033` (the small shape), `810_142` (the board regression that
named it), `395_001` (keyword `assert` inside `test` stays a transform).

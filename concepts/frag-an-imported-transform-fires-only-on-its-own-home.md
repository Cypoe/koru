---
type: belief
id: frag-an-imported-transform-fires-only-on-its-own-home
provenance: inner-test keyword-resolve session 2026-09-07 — keyword-tor carve-out closed once test clones resolve before run_pass
ts: 2026-09-07
tags: [koru, transforms, dispatch, module-qualifier]
---

# An imported transform fires only on its own home (belief)

A transform that lives in an imported module matches an invocation only when
that invocation spells the transform's module. Same bare event name in a
sibling module is a different event. The one remaining bare-segment exception
is globs: taps capture user events by design.

`[keyword]` is not a dispatch exception. The user spelling is still the bare
name (`assert`, not `std.testing:assert`); keyword-resolution rewrites it to
the transform's home, including inside a `test` body. The cloned body is a
fresh parse and used to skip that pass, so qualifying `assert` made the inner
`run_pass` miss (395_001). That hole is closed: the clone is resolved against
the parent program's registry before the inner pass. The keyword-tor carve-out
on the dispatch table was compensating for the skip, not a ruling that
keywords should steal.

A keyword that is also a `[transform]proc` was already on this side of the
line. `std/store:take` is a keyword *and* a proc; `std/string:take` is a
different event (690_053). The proc path never used the bare gate. Closing the
tor carve-out makes the two mechanisms agree about dispatch, without settling
the marking fork in [[frag-two-mechanisms-mark-a-transform]].

This is the same soundness the `[transform]proc` path already had
(qualified-only, never a bare capture). Transform *tors* on the legacy gate
matched the segment and ignored the home. That is a capture. `std/list:free`
rewrote `std/map:free` onto a list trunk name that map does not own. The
program that wrote the real spelling was innocent.

What would `correct` this: a ruling that a library transform may rewrite
every module's same-named event on purpose — a global `free` / `get` / `new`
as one compiler pass. Until that ruling, a cross-module fire is a defect.

Pins: `660_033` (the small shape), `810_142` (the board regression that
named it), `395_001` (`assert` inside `test` still fires, now via resolve
rather than a bare gate), `690_053` (keyword-proc `take` stays on its own
home).

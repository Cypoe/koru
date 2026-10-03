---
type: belief
id: frag-the-catch-layer-is-a-verdict
provenance: bakeoff session 2026-10-03 — first mechanized matrix run: 4 bug classes × 4 stacks, seeded naive programs, verbatim logs under bakeoff/out/
ts: 2026-10-03
tags: [oracle, diagnostics, bakeoff, comparison]
---

# Where a bug is caught is a verdict tier, not a property of the bug (belief)

The question a comparison answers is not "does the toolchain catch this" but
"**which layer catches it**." The same naive program — a value touched after
its custody moved, a tainted string reaching a sink — produces different
verdicts on different stacks, and the verdicts form a ladder:

```
compile-refuse  >  compile-warn  >  runtime-catch  >  silent
```

Measured 2026-10-03 (`bakeoff/`, first run): Koru refuses all four seeded
classes at compile time; Rust refuses three (the taint cell has no naive
refusal — it needs a hand-rolled newtype, and discipline is not a
conversation); C#/.NET refuses two and catches a third only as
`ObjectDisposedException` mid-run; Go refuses one and **runs the
use-after-dispose cell to a clean exit while the write is silently dropped** —
the worst tier, and the one no other arm produced.

## The scope rule is the honesty rule

The corpus measures **naive programs** — what a competent developer writes by
default. Typestate, Drop guards, newtype wrappers, linter oracles are all
excluded not because they don't exist but because requiring them moves the
claim from "the language refuses" to "the language can be made to refuse by
someone who already knows the answer." The 2104 shootout family carries the
best-effort variant and records where even hand-built guards fail
(`let _ =` suppressing `#[must_use]` entirely). Both measurements are needed:
naive for the default experience, best-effort for the ceiling.

## The matrix audits the auditor

A cell where our own conversation is weakest stays in the matrix as an open
finding. `type_mismatch` refuses — but the refusal is Zig's, in
`output_emitted.zig` coordinates, because the mismatch escapes the frontend.
That row is not a win; it is a named gap that survives until a source-mapped
KORU diagnostic replaces it. The instrument that cannot record its own
weakest cell is advocacy, not measurement — the shootout already proved this
once (`2104_12/13` found the same wound and the fix landed 2026-08-10).

## Falsifiable edge

If a rival arm gains a refusal — a new rustc lint, a Roslyn analyzer, a Go
vet check — the matrix must show it on the next run. An instrument that only
records wins is dead. The matrix is a standing oracle precisely because it
can move against us in both directions: a Koru cell downgrading to
emitted-coords is as visible as a foreign cell upgrading to refuse.

## Open

- Whether `type_mismatch` wants a frontend type-checker fix or backend-error
  source-mapping (or both) — ruling pending; the cell stays as the pin
  regardless of which lands.
- Two bug classes named but unseeded: unordered protocol steps
  (commit-before-open) and unhandled outcome arms. The 2104 family already
  owns the protocol-shape cells by hand; whether they join the mechanized
  matrix or stay verdict-doc is a scope call.
- The runner's runtime tier is binary (exit 0 = ships). "Silent wrong" vs
  "correct" needs a declared expected-output per cell if the corpus ever
  includes non-buggy controls.

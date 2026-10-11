---
type: belief
id: frag-verification-participation-is-declared-not-selected
provenance: verify-path session 2 2026-10-11 — Lars ruled the surface shape (enforce, explain, |c[verified], no --lang=c) while reviewing the open questions
ts: 2026-10-11
tags: [koru, verification, compcert, variants, comptime, enforce]
---

# frag-verification-participation-is-declared-not-selected

A verification arm is not a language target, and joining one is a
declaration in source, not a flag on the toolchain.

The C lane was drawn as `--lang=c`: a fourth column on the variant
grid next to `zig`/`js`/`cs`. That spelling carries a lie — `--lang`
selects which *product binary* a build produces, and the verified arm
never produces a shippable artifact (the oracle's output is a test
instrument; CompCert's license bars shipping it anyway). A target you
cannot ship is not a target. It is an instrument wired into the
pipeline.

Once that is named, the surface rearranges:

- `|c` remains a proc-body variant tag — a hand-written C impl,
  parallel to `|zig`.
- `|c[verified]` pins one unit to the verified pipeline — the bracket
  selects the toolchain arm (`|mlir[gpu]` precedent), and a missing
  verified arm refuses.
- `~[debug]std/witness:enforce` declares program-wide participation —
  a comptime tor invocation in the `std/build:variants` family whose
  presence injects the dual-arm pass into the pipeline.
- `std/witness`'s own `~[comptime|command]` tors are the lens —
  `koruc program.k witness` renders the routing before any arm runs.
  The module *also* ships an `[explainer]` tor so the shared
  `explain` catalog shows a witness section — participation in the
  tour, never the driver of the module's own surface.

The consequence that matters: verification becomes a *property of the
program*, not of how the compiler was invoked. A regression cell
declares `enforce` in its source; no `LANGUAGES` marker or flag
combination is the load-bearing fact. The evidence axis lives in the
program — where the obligations are — and the verdict axis stays
invariant underneath it: `enforce` selects how much evidence is
required, never whether checking happens.

## Open questions

- `enforce` body contents (empty = all proven fragments vs explicit
  list) and its outcome-branch vocabulary.
- Whether any harness-internal spelling for "emit the oracle arm"
  survives the collapse (plumbing, not surface). (`--lang=c` as an
  emitter toggle is fine as plumbing — the ruling barred `c` as a
  shipping column, not as a build spelling.)

## Deflated 2026-10-11 (Lars): whole-program first, partition parked

The unit-partition shape — `|c[verified]` per-unit pins, per-tor
routing, coverage maps — bought coverage granularity at the price of
new language surface for a toolchain-QA need. Lars parked it: build
the whole-program C lane for the sequential fragment first; `enforce`
keeps its meaning ("verify this program" = emit the C twin, ccomp,
diff) which is arm-shape-agnostic. The partition machinery returns
only if measured refusal rates prove the wall costs too much — the
lowering code carries over either way, whole-program being the
degenerate case.

## Lineage

- Refines `frag-a-verified-oracle-covers-units-not-programs`: that
  frag made coverage per-unit; this one makes participation
  source-declared. Together: the program says which units get the
  verified arm, and the toolchain flag disappears.

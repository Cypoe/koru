---
type: belief
id: frag-the-check-verdict-is-staged
provenance: an external composition fuzzer scored programs on `koruc -c` and
  reported hits the backend then refused (KORU022 post-transform, KORU173/205
  at emit); the -c/backend split is by design, which makes -c the wrong oracle
ts: 2026-10-01
---

# The check verdict is staged, and `-c` only speaks for the first stage (belief)

`koruc -c` answers "does the frontend like this program" — parse, frontend
flow-check, done. It is not "will this compile." Proto/refine field grammars
(KORU173/205), emit-stage refusals, and the missing-branch half of coverage
(KORU022) all live *behind* the `-c` exit: missing-branch is deliberately
post-transform because transforms and auto-discharge legitimately synthesize
satisfying arms.

The unknown-branch half of coverage moved the other way, 2026-10-08: KORU021
on a source-spelled arm name now fires at frontend, in `.frontend` mode,
*before* transforms run. The reason is asymmetric with the missing-branch
reason — a transform can synthesize a satisfying arm, but a transform can
also *consume* an unsatisfying one. `is_transformed_subtree` blinds every
post-transform walk to the subtree it marks, and a transform-consumed arm
carries the user's misspelled branch name into exactly that blind zone
(510_125: `| captured` consumed an `if` arm naming `| missing`; the arm
silently dropped and the program died on an unrelated backend type error).
Judging arm names can only happen where the names still exist.

Two refinements ride with the move:

- `[transform]` callees are exempt from the frontend arm sweep — their arm
  names bind branches on decls the transform *generates* (`renderHTML`'s
  `| rendered`), so no source-visible vocabulary exists to judge them
  against. Their contract is the transform's own shape check.
- The verdict is now staged *by check class, not by checker*: one KORU021
  message, two pipeline homes — frontend for source vocabulary, backend for
  the synthesized-arm landscape.

A fuzzer that scores on `-c` therefore manufactures false hits: every program it
calls a find is one the real pipeline might refuse a stage later. Measured on
regenerated corpus compositions — five `branch_arm__obligation` exemplars, all
`-c`-green, all refused only once the backend ran.

`--deep-check` is the honest oracle for that consumer: the full pipeline runs —
transforms, check-flow, emission — and only the final `zig build` of the
emitted program is skipped. The verdict is the compiler's own, at ~0.4s warm
against ~1.2s for a full build and ~0.14s for the `-c` verdict that lies.

## What follows

- **A check flag names the stage it stops after, not the rigor it applies.**
  `-c` was never the compile verdict; it only looked like one because nothing
  downstream had a consumer that compared.
- **The remaining blind spot is native codegen.** Emitted Zig that `zig build`
  rejects is invisible to `--deep-check` too — a fuzzer hunting miscompiles of
  the emitted form still needs a full build or its own zig oracle.
- **Same lesson as frag-frontend-checkers-see-one-file-not-the-program, one
  axis over:** that belief is about *file* scope (one file, not the program);
  this one is about *pipeline* scope (one stage, not the compile). Both are
  the same shape — a verdict silent about what it never saw.

---
type: belief
id: frag-invariant-pure-steps-may-hoist
provenance: binarytrees autopsy → owned-value port → hoistInvariantLoopPrefix
  (d021044), 2026-10-25/26. Session error worth recording: the pure-tree shape
  was first declared inexpressible ("no recursive unions"); Lars corrected it —
  `grid` already proves data types are a library lane carrying chosen
  semantics, and avoiding them was posture, not a boundary.
ts: 2026-10-26
---

# Invariant pure prefixes of `for ! each` may hoist — the obligation system is what makes the question answerable (belief)

When a `for ! each` body's leading steps never read the item and reach no
`stored`/`captured`/io through their callee chain, the compiler may evaluate
them once before the loop. This is GHC's full-laziness move, but spelled
through machinery Koru already had, rather than assumed by a runtime:

- **Invariance is a dependence check** — no arg mentions the item or `__it`.
- **Cleanliness is the same flood `[parallel]` runs** — same-module flow
  impls whose transitive callees stay clean, control builtins pass through,
  denylisted effect names stop the prefix. Recursion edges are `.visiting`,
  not dirty.
- **`<owned!>` mints are hoist-clean by ruling.** A mint looks effectful —
  it allocates — but an `owned!` return is a liveness interval
  ([[frag-an-obligation-is-a-liveness-interval]]), and its discharge is
  movable to the loop's `| done`. Mint…borrow…discharge once is observably
  the same as mint…borrow…discharge per iteration *when the produced value
  feeds only pure reads*; the obligation checker is what makes that claim
  decidable instead of hopeful.
- **The prefix, not the body, is the unit.** Item-dependent tails (`captured`
  folds, item-bound calls) stay in the loop untouched — `400_222`/`400_223`
  pin both directions, and `400_222` was verified to fail with the pass off.

## What it bought, measured

The owned-value binarytrees port — a `struct` + `mint`/`free-tree` obligations,
ordinary Koru, no arena — ran the unmodified Haskell-shaped source at ~2.8ms
down from ~482ms, checksum-identical, in Haskell's 1.8ms tier. The Haskell row
was never an allocator trick: `check (make 13)` is loop-invariant, GHC floats
it, call-by-need shares it. Koru can now make the same move where the spelled
effects permit it — and refuses silently-by-omission where they don't (the
item-bound or effectful prefix simply stays).

## The sharable belief

Two compiler capabilities — `[parallel]` partition legality and invariant
hoisting — are the same question wearing different costumes: *does this region
reach shared mutable state?* Koru's effect-spelling makes both transformable
*and* rejectable; languages without it choose between unsound motion and no
motion. Expect more passes to land here — the flood is the shared engine.

## What would correct this

- If allocation count ever becomes observable semantics (an allocator-
  pressure benchmark as a language contract), hoisting a mint changes
  observable behavior and the mint-cleanliness ruling is wrong, not just
  incomplete.
- If a `<!owned>` discharge can have drop-order effects (destructors with
  observable behavior beyond reclamation), moving it to `| done` is not
  observably identical.
- Arm-carrying steps and non-`each` loops are unhandled (v1 refuses them) —
  widening, not correction, unless a case shows the refusal was wrong.

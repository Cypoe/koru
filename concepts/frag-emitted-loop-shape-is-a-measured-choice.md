---
type: belief
id: frag-emitted-loop-shape-is-a-measured-choice
provenance: clbg_nbody kernel port, 2026-10-23 — std/kernel pairwise emission
  flipped `for` capture loops to `while` after a 5% deficit vs the hand-tuned
  driver was traced to the loop-construct spelling itself
ts: 2026-10-23
---

# The emitted loop's construct spelling is a measured choice, not a stylistic one (belief)

`for (0..N) |i|` and `var i: usize = 0; while (i < N) : (i += 1)` are
semantically identical Zig, and they are NOT performance-identical. On
clbg_nbody's triangular pair loop (5 bodies, 24M steps, ReleaseFast, arm64)
the `for` spelling landed 0.66s and the `while` spelling 0.63s — a stable ~5%,
checksum-identical output. The mechanism is LLVM unrolling/scheduling luck on
the loop nest shape, not anything a source-level reading can predict.

Two corollaries measured the same day:

- The "obvious" optimizations were wrong. Register-accumulating the i-side
  velocities (the hand-tuned driver's distinctive trick) measured FLAT in the
  kernel's context — LLVM had already promoted the per-pair stores — and
  fusing position advance into the pair pass measured 0.89s, *worse*, because
  scalar accumulation defeats the pair loop's SLP vectorization.
- The const-guard is not free. Re-binding loop counters through
  `const i = __koru_i` (to preserve for-capture const-ness) restored the
  entire 5% deficit — the extra binding is exactly what makes LLVM treat the
  loop like the `for` form again.

So kernel emission writes `while` for pairwise loops (block-scoped so `var i`
doesn't shadow a following `for |i|` capture or collide with a second
pairwise), and the rule generalizes: when a hot emitted loop exists, its
construct spelling is a measurement to make and record in a comment at the
emit site — because a later reader "cleaning it up" into the idiomatic form
will silently revert the optimization, and nothing at the Koru source level
will tell them the shape was load-bearing.

Open question: whether `while` is systematically better or nest-shape-specific.
Measured once, on one benchmark; other kernel workloads may land differently —
re-measure before extending the choice to `self`/`step`/`reduce` emissions.

---
type: belief
id: frag-the-vectorizer-checks-the-emitted-shape-not-the-structure
provenance: Goose-race base64, 2026-10-22 — a faithful replica of Koru's
  emitted call architecture (event handler per group, 13-field write-unit
  call, _ = &x keepalives, slice-window reslicing) vectorized at full speed;
  the same loop with i64-returning codec fns or select-chain produces stayed
  scalar at 4-6x the instructions.
ts: 2026-10-22
---

# The vectorizer checks the emitted shape, not the call structure (belief)

When a Koru loop compiles 4x behind a reference codec, the first suspects are
the visible architecture: per-element event-handler calls, struct argument
marshaling, keepalive discards, the write-unit call. Bisection on the real
emitted file plus a hand-built replica showed **all of those are free** —
LLVM inlines through handler structs, struct args, and `_ = &x` without
residue, and a loop built from exactly Koru's emitted pieces ran at the
hand-written binary's speed.

The two properties that actually decided vectorization, both invisible at
the architecture level:

- **Lane width.** Codec results computed as `i64` force i64 vector lanes
  (2-wide) or scalar fallback; the identical computation on `u8`/`u32`
  vectorizes 16-wide. Width is a *type* decision, so it sits in the
  arithmetic expressions and tor signatures — not in any call.
- **Produce shape.** An if/else-if produce-cascade (`cond`'s emission) that
  early-returns the mapped value vectorized for one loop and refused for the
  other; the semantically identical select-arithmetic expression
  (`@intFromBool` terms summed in `u8`, wrap carried by a `u16` widen +
  `@rem`) vectorized both. Which spelling LLVM's cost model accepts is
  empirical — the only oracle is the emitted asm (`st3`/`st4` interleaved
  stores on this host) plus instruction count, not intuition about "simple"
  vs "complex" code.

The consequence for performance work: **bisect on the emitted file and a
minimal replica, not on the architecture narrative.** Each hypothesis got a
binary and an instruction count; four were falsified before the real ones
surfaced. And the ordering holds — a mock can clear a suspect (the replica
proved calls free) before the real emit pays to test it, but only the real
emission pronounces. Cousin of `frag-the-assembly-grammar-decides-which-
hardware-exists` — there the missing path was an asm spelling, here it is an
ordinary emission shape: the hardware unit exists; the question is always
whether the emit spells something the vectorizer admits.

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

## 2026-10-22 — counted-for emission: honest, not faster

Follow-up on the same loop, one level up: the `std/grid:walk` driver's
`while (s.len >= n and d.len >= m)` reslice guard was suspected of blocking
unrolling, since clang's equivalent runs 2x unrolled. Rewritten as a counted
`for (0..@min(len/stride))` it emits identically — and LLVM still keeps 1x
unroll, zero speed change. The keepable residue of the experiment: the
counted trip is *real* (computable at entry, provably safe for the raw
accesses), so the driver joined the for-class the emit-for-not-while gate
prefers and its exemption row retired. But "guard shape is the unroll
blocker" joins the falsified list: the residue that remains — ~15 vector
instrs per 16-group iteration — is the select-arithmetic `symbol` cascade,
~12 ops vs clang's ~8 on `bit`/`bsl` selects. Three select spellings
(early-return, nested if-expression, arithmetic-only) all failed to
vectorize in this loop context; the arithmetic form is the only lane LLVM
admits, and it costs what it costs. A per-iteration instruction count on
the emitted asm remains the only verdict here.

## 2026-10-22 — bound two-way ifs: the select lane LLVM always had

The "arithmetic is the only admitted lane" verdict above is reversed. The
distinguishing property was never select-arithmetic vs conditional — it is
**merge arity**. `cond`'s early-return cascade and the else-if expression
ladder both emit multi-predecessor merges, and SimplifyCFG only folds
two-pred diamonds — so ladders stay CFG branches forever, and three of the
four spellings failed for that reason. The admitted spelling: **bound
two-way ifs** — each level `const r = if (c) x else acc` where `acc` is the
previous bound const. Every level is a clean 2-pred diamond; SimplifyCFG
folds each to a `select`, the chain becomes select-accumulating IR, and
NEON lowers it to `bit`/`bsl` — instruction-identical in kind to clang's
lowering of Goose's ternary cascade (~8 ops/symbol vs ~12).

The pure-Koru spelling exists: `|> idv8(v: if (c) x else acc): r` — the
identity tor binds the if-expression to a const step by step. `symbol`
and `value` in the base64 kernel took this form; encode phase dropped
171→116ms and the whole-process race went 1.10×→0.98×, with the checksum
and bad=0 verify unchanged. The general recipe: **whenever a Koru produce
needs a multi-way value dispatch that must vectorize, spell it as bound
two-way ifs accumulating through else-arms — never as a cond ladder or an
else-if expression chain.**

---
type: belief
id: frag-compiler-flags-baked-into-backend
provenance: floated 2026-07-14 while adding the --release gate (feat(prototype)); Lars parked it as low-priority, pin the observation in prose
ts: 2026-09-08
---

# Compiler env is runtime data; the bake is gone (belief, evolved)

2026-07-14 belief (superseded, was valid): flags/env baked into the backend as
comptime consts, buying dead-strip elimination of flag-gated paths at the price
of a backend rebuild per flag-set. Parked because the recompile cost looked
tolerable and the tradeoff was honestly described.

2026-09-08 ruling: the price was mismeasured and the benefit had no customers.
Rebuilds were forced not only by real flag flips but by the injected `command=`
atom — the everyday compile-then-run verb change rebuilt the backend, ~7s
against a ~1s cache hit, measured both directions. And no caller ever fed a
flag into a type-level position, so the comptime dead-strip never fired for
anyone; the caller audit sits in the unbake commit. The env now rides the
program-AST JSON channel, one backend serves every flag combination, and the
old cross-serve poisoning is unrepresentable rather than keyed-against.

What would reopen this: a caller that needs a flag at type level — an
elimination that actually fires, or a comptime-only position. Then the tradeoff
returns for real, and the answer is a comptime accessor alongside the runtime
default, not instead of it.

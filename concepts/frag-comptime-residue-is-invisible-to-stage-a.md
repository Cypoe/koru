---
type: belief
id: frag-comptime-residue-is-invisible-to-stage-a
provenance: the residue-continuation rung, 2026-10-16 — a `mul |> add |> print` chain compiled clean and emitted a skeleton: folded once, promoted residue still comptime-owned, silently dropped
ts: 2026-10-16
---

# A comptime flow's residue is born after Stage A's ownership scan — the fold must consume it to fixpoint or drop it loudly (belief)

Stage A's emitter decides interpreter ownership on the pre-fold AST:
`flowIsInterpreterOwned` marks a flow whose head is a `[comptime]` event as
"do not emit — the interpreter owns this." Stage C's folder then consumes
the head and promotes the residue continuations into a new flow. The residue
was never in Stage A's scan. If its head is *also* `[comptime]` — the
completely ordinary case of one comptime call chaining into another — the
emitter still owns it and emits nothing, while the folder has already moved
on. The flow evaporates between the two predicates: compiled clean, binary
prints a start/end skeleton, zero diagnostic.

Ownership across a stage boundary is a **fixpoint decision**, not a single
pass. The folder must keep consuming — fold a bare-return impl, walk a
subflow impl, call a proc handler through the thunk table — and re-examine
the promoted residue's head each time, until what remains is not comptime.
Each step strictly shrinks the flow, so it terminates. And when a residue
head is `[comptime]` with no executable implementation of any kind, that is
a loud wall at the fold site — never a silent drop, because the silent drop
is the exact defect this belief exists to kill.

## The residue contract does not care which engine produced the result

Fold, walk, and thunk all produce a `ThunkResult` — optional branch,
optional payload — and one `spliceResidue` dispatches the residue on it:
a `|>` chain gets the payload substituted at the return binding; named
branch arms are dispatched at compile time exactly as the runtime would,
and the matched arm's chain promotes with its binding metadata cleared.
A `-> T` bare return carries no tag, so every named residue arm is a
candidate and when-guards select — the same convention the walker uses
inside a subflow body.

## Substitution is a lexical act, not a textual one

Splicing a folded value into continuation text must skip what is not a use:
plain string prose, and the `:spec` position inside `{{ ... }}` templates —
`"{{ d:d }}"` with `d` bound must become `"{{ 4:d }}"`, never `"{{ 4:4 }}"`
(the spec `d` is a format letter; substituting it produced `{4}` positional
format text and a host-compiler error instead of a Koru one). String state,
mustache depth, and format-spec mode are tracked while scanning. A binding
name inside a string literal *nested* in a template expression is a known
unsplittable edge — it substitutes wrongly today, loudly fixable when a real
program hits it.

## Open rungs

- Catchall residue arms (`| _`) wall loudly rather than matching.
- Shape-destructure arms, named-field `=>` constructors, and `-> name v`
  named produces inside walked arms are later rungs — all loud.
- The `| go i` convention on a `-> T` call site (310_091's guarded +
  fallthrough pair) is pinned in the evaluator's dispatch semantics but
  refused upstream by KORU021 — the checker's ruling, not this rung's.

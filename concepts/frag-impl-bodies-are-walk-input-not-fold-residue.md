---
type: belief
id: frag-impl-bodies-are-walk-input-not-fold-residue
provenance: stack dogfood probes (2026-10-17) — probing walk-path obligation
  checking produced a backend SIGABRT: `flow.inv()` on a branch_constructor
  head. Fixed in comptime_eval.zig, pinned 310_135.
ts: 2026-10-17
---

# Impl bodies are walk input, not fold residue (belief)

`fold`'s item loop consumed every interpreter-consumable flow by shape — a
`[comptime]` head on a foldable tor — including impl flows (`foo = lit() |
ok v => result v`). But an impl body is a *definition*: the walker enters it
through the tor's call site and its `=>` producer arms construct the
tor's result — they are the impl's return mechanism, not residue to splice.
Folding an impl head promoted the `=>` arm to the flow root, leaving a body
whose head node is `branch_constructor` — violating the invariant
`Flow.inv()` asserts (a flow's site head is always an invocation).
Every later scan calling `inv()` panicked; the backend died SIGABRT with no
diagnostic.

The rule this mints: **the fold boundary is drawn at `impl_of`, not at head
shape.** A flow is residue material only when it is a call site; the moment
`impl_of` is set, the whole body — head, arms, `=>` producers — belongs to
the walker, and the walker's own `branch_constructor` arm handler (which
fold could never reuse) is what evaluates it. Two engines, one rule each:
fold rewrites call sites, walk executes definitions.

The sibling wall that fell out: a `=>` arm under a *non-impl* flow still
reaches promotion — and there a producer arm is meaningless, not
unimplemented. The refusal names that: "a producer arm has a result slot
only inside a tor impl." Same checkpoint, different verdict per side of
the boundary.

Related: [[frag-comptime-residue-is-invisible-to-stage-a]] (why promoted
residue must re-enter the interpreter loop — this frag is the mirror: why
impl bodies must never enter it).

---
type: belief
id: frag-the-at-namespace-is-the-compilers-side-channel
provenance: koru session 2026-10-03 — Lars ruled on the marks-channel migration after auditing the four `@`-strings riding the user-writable annotations field (compiler-marks branch)
ts: 2026-10-03
tags: [koru, annotations, marks, architecture, language-design, ruling]
---

# `@` is the compiler's side-channel — opaque by design, unspellable by rule (belief)

**The ruling (Lars, 2026-10-03):** the `@`-prefixed strings (`@scope`,
`@pass_ran`, `@shape_valid`, `@preamble_then_call`) are the compiler's
internal mark channel. They ride their own AST fields (`marks`,
`binding_marks`), never `annotations`. Surface `[@x]` is refused with
PARSE012 — a user spelling one asserts pass-produced state, which is a
lie the syntax must not let stand.

## Why opaque, not deconstructed

The migration deliberately did NOT turn marks into bools/enums on the
structs, and the reason is structural, not aesthetic: `std/compiler:
coordinate` is `[abstract]` — user-overridable. Custom pipelines exist
and must be able to invent their own marks (`@my_pass_ran`,
`@vouched_by_x`) without a compiler release or an AST schema change.
koru_std already exercises this — it stamps marks with open prose
payloads (`@shape_valid("capture dissolves ! as / | captured into cell
preamble + assignments")`) that no closed enum could carry. The opaque
string channel IS the plugin API for pass authors. MLIR attributes and
LLVM `!metadata` are the same pattern: every mature staged system keeps
one untyped side-channel so the core schema doesn't absorb every
handshake between middle layers.

## Why node-local in the tree, not a ledger

Koru's AST is a staged artifact, not a static syntax tree — the same
tree is matched, spliced (taps weave, template splices), cloned,
serialized to `program.ast.json`, and re-consumed by minted backends.
Each mark is a node-local *witness* of its own elaboration history
(`@pass_ran` is a termination witness for the expansion fixpoint —
without it transform matching infinite-loops; `@shape_valid` is a
certificate relocating *who* guarantees shape validity; `@scope` is an
execution-multiplicity witness; `@preamble_then_call` a
transform↔emitter contract). A fact that must survive a transplant can
only live on the node; a pass-ledger would break on the first graft.
In a staged pipeline, elaboration history IS semantics — which is why
marks serialize and clone like every other field.

## What would correct this belief

- If a legitimate need for user-spelled marks appears, the answer is a
  non-`@` spelling — `@` is the provenance marker by convention, and
  that reservation is the point. (This already narrowed one plan: the
  deferred user-facing scope declaration lost its chosen `[@scope]`
  spelling the day this channel was ruled — see
  OUTSTANDING_DESIGN_DECISIONS.)
- The graduation rule stands: a mark earns a typed field when multiple
  independent pass families consume it, its payload needs structure,
  or the fact becomes user-meaningful. `@scope` (several consumers,
  semantics-grade) and `@preamble_then_call` (really a two-mode enum)
  are nearest that boundary. Graduation does not weaken the channel —
  it exists for the next mark nobody has written yet.
- If silent drift accumulates — typo'd marks that stamp fine and match
  nothing — the correction is a registry (manifest of produced ↔
  consumed marks, asserted by test), not typing. That manifest is
  **unbuilt** as of this writing; the channel's failure mode
  (stamp-and-vanish) is currently unchecked.

## Boundaries of the ruling

- Template DSL `[scope]` is pass-authoring surface and stays spellable —
  template processors are themselves internal producers. The prohibition
  covers `.kz`/`.k` surface `[@name]` only.
- koru_std code writes `.marks` directly and *should* — koru_std is a
  pass author, the canonical third-party consumer of the channel.
- The sibling wire is untouched: `//`-comment markers riding
  `program.items` are a separate, still-open audit
  ([[frag-comment-markers-are-the-inter-transform-wire]]).
- Related but distinct: the `[transform]`/type-driven fork
  ([[frag-two-mechanisms-mark-a-transform]]) is a user-surface question
  and stays an open fork — this ruling governs the internal channel only.

---
type: belief
id: frag-a-shared-word-across-slots-is-a-reader-collision
provenance: ruled by Lars 2026-10-17 — the `[requires]` vs `std/compiler:requires`
  collision cypoe surfaced in the pass-graph rungs was resolved by namespacing
  the annotation (`contract:requires`), not by picking one word over the other
ts: 2026-10-17
---

# Two surfaces sharing one word collide for the reader even when the grammar never confuses them (belief)

**Ruling.** An annotation name may be namespaced: `[contract:requires("x")]`,
`[contract:preserves("!flow")]`, `[contract:obliges("kind-stable")]` are the
spellings for declared-contract claims on tors and transforms. The `:` prefix
does the disambiguation — the annotation parser already carries qualified
names (`[registry:scope(...)]` precedent), so namespacing costs no grammar
work and buys family coherence.

**Why a namespace and not a synonym.** Two collisions were live, not one:

- `std/compiler:requires` (build-dep directive tor, call position) vs
  `[requires]` (pass-graph ordering edge, annotation position). Disjoint
  slots — the parser was never wrong — but `~[requires("x")]tor a` reads
  "needs x to build" to a human. Renaming to `runs_after` would have fixed
  this and left the second collision.
- `depends_on` (build steps, store rules) is taken: it means *schedule me*
  — the system topo-sorts from the edges. The pass graph means *validate
  the order I authored* — refusal, never reorder. Reusing `depends_on`
  would mislead worse than `requires` did: same arrow, opposite contract.

The `contract:` namespace solves both at once and names what the
annotations actually are — claims the toolchain discharges (the
diagnostics already called the annotation "the contract"), joining the
existing claim-stamp idiom (`[measured]`/`[proven]`/`[aspirational]`).

**Open question parked deliberately:** the witness wire tokens
(`pass-graph-edge X requires Y`, `preserves=`, `obliges=` field names in
`transform-app` lines) keep the unnamespaced words — machine-facing
vocabulary the attested corpora and `WitnessCheck.lean` already parse.
Renaming them is a second knob, decoupled from the surface spelling.

**The legacy refusal is part of the ruling.** A bare `[requires]` now
refuses by name (`220_073`) — an unnamespaced claim that parses but binds
nothing would silently become an unchecked contract, which is the same
failure class as the passthrough-flag bucket (see
`frag-passthrough-flags-swallow-conventional-spellings`).

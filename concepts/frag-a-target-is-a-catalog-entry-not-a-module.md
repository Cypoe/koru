---
type: belief
id: frag-a-target-is-a-catalog-entry-not-a-module
provenance: c-lane rungs 12-15 (2026-10) — capture, non-range for,
  switch, nested capture each landed by teaching ONE emitter what the
  others already knew; measured 2026-10-24: c_emitter.zig (2.9k) and
  cs_emitter.zig (4.5k) share ~60% walker-shaped code, ~40% target data
ts: 2026-10-24
tags: [koru, targets, emitters, catalog, k3, design]
---

# A target is a catalog entry, not a module

Four rungs of c-lane work kept repeating the same repair: switch's zig
scaffolding, capture's preamble channel, the `outer-val` mangle — every
one a place where *two* emitters needed the same semantic decision and
only one had it. The emitters are the N-writers defect at architecture
scale: `resolveInlineMarkers` and `emitInlineCodeResolvingSplices` are
two resolvers of one marker grammar; the optional-injection rule existed
in four copies. `frag-a-name-mangling-dispatcher-assumes-a-parity-nobody-
maintains` named it at rule granularity; this is the same shape at file
granularity.

The measured split: what an emitter contains is ~60% **shared quotient
machinery** (site/continuation traversal, `__koru_inline`/`__koru_continue`
marker resolution, `.terminal` tombstones, snapshot semantics, cell
registries, tagged-dispatch shape) and ~40% **target data** (type table,
name mangles, builtin table, prelude, fragment/refusal policy). Nothing
today *declares* which part is which — a per-target `.zig` module fuses
both, so every lane re-derives the quotient alone and drifts.

The ruling (greenlit 2026-10-24): **two parts, mirroring `std/realize`'s
solver/policy split.**

- `std/target` — the catalog. Declared arms; each arm is a row set:
  identity (facet ext, artifact name, toolchain), type spellings incl.
  cell-minting schemes, name mangles, builtins, prelude, construct
  dialect pointer, fragment policy (the named refusals = the arm's
  promise boundary). `std/target:c` is data; the zig lane is arm `zig`,
  not a privileged default — `target-of` resolving to `zig` is the same
  lookup as resolving to `c`.
- `std/emit` — the generic walker (name resolved: the verb, inline
  with the rest of the module naming).
  Target-blind machinery reading rows; it does not know C exists.
  Not a `std/compiler` part: `compiler:emission` owns the coordinate
  flow (when, in what order — already an overwritable tor); the
  emitter is the engine it calls.

Lookup spelling ruled 2026-10-24: `std/target(name)` — `pub tor
default` makes the module name itself callable; the catalog IS the
lookup, no `std/target:of` helper.

First live consumer measured (2026-11): `compiler:emission`'s dispatch
now asks the catalog — `target-of`'s `c` arm checks `target(c)` is
declared (absent catalog advisory, missing row on a loaded catalog is
`driftLog` drift while the arm still wins, matching the dual-answer
phasing) and `emit-c` returns the row's declared `artifact` field, which
`emit-c-artifact` hands `write-artifact` — the artifact name is no
longer a literal in the chain. The catalog loaders themselves moved out
of `c_emitter` into the walk's engine (`emit_walk`), target-parametrized
— the lane supplies `"c"`, the engine owns the reading. The claim later
widened to every arm (2026-11): `target(zig|js|cs)` rows are declared
and `target-of` audits each arm's row through one helper
(`emit_walk.auditTargetArm`) — the arm still wins on drift, matching
the dual-answer phasing. Each `emit-*` chain now returns the row's
`artifact` field into `write-artifact`, and the Stage-D drivers
(`host-build-zig|cs`) resolve the same answer via an optional `name`
param that falls back to the catalog row before the literal — a direct
override call without `name:` still names the file the row declares.
The lang-name string select remains, but it now *indexes* declared
rows rather than standing beside them.

Two parts rather than one because the differences are real: catalog rows
are data that changes per target and per added arm; the walker is
semantics machinery that changes rarely and dangerously — one file means
every new arm edits the walker. The refusals differ too: "no row
declared" is a coverage gap with an obvious fix; "walker cannot express"
is an engine gap — different messages, different owners.

The phasing this permits (Lars's "implement in Zig first, then purify"):
catalog extraction works while the walkers are still `.zig`; walker
unification folds the ~60% shared code into one engine next;
Koru-authored `std/emitter` last — three independent rungs, each
reversible.

The K3 angle is why the split matters and not just tidies: FlowDialect
pairwise congruence runs over *declared rows*. "The zig and c lanes agree
on the shared fragment" reduces to "their catalogs' overlapping rows
denote the same quotient classes" — a proof-sized object. A 2.9k-line
zig emitter is not re-decidable in Lean; a row set is.

Open: whether the catalog's construct row names the `|c` template
dialect (control.targets.kz already declares `for|c`) or inlines
spellings — the facet mechanism may already BE the construct row, making
the catalog an index over what facets declare.

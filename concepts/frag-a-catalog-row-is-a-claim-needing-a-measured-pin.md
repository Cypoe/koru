---
type: belief
id: frag-a-catalog-row-is-a-claim-needing-a-measured-pin
provenance: the std/target catalog grew a `construct` verb whose `"supported"` rows name which surface constructs a target lane answers; the gate asked who ruled those spellings
ts: 2026-10-25
---

# A catalog row is a claim, and a claim needs a measured pin

`std/target`'s `construct(c)` row is the C lane's declared coverage: a
`"std/store:take": "supported"` entry asserts the lane lowers that surface
construct. That assertion is a claim like any other in the tree — it is
ruled only when a regression pin measures it.

The ruling, decided with the provenance rung it landed on:

- **`@from_construct("std/<mod>:<verb>")` is the ruled internal mark** a
  transform stamps on an invocation it mints, so the emit walk can ask the
  catalog by the surface key after the surface name has been lowered away.
  It is pass-internal metadata (`.marks`), never authorable surface syntax,
  and must never appear in emitted host text.
- **A stamp is provenance, not a claim.** A transform whose construct has
  no C-pinned regression still stamps its mint — but the catalog carries no
  row for it. That is the designed dormant state: the walk reports the
  unclaimed ask, the catalog claims nothing.
- **A `"supported"` row is added only with the pin that measured it.**
  Current pins: `stored` 690_001/010, `insert` 690_011/022/043,
  `watch` 690_001, `take`/`query` 690_070 + 690_075, `rule` 690_336.
  `stripe` and `preorder` are stamped and deliberately rowless — no C test
  exercises them yet.

Resolved open question (the splice vocabulary was unnecessary): on the
C lane `watch` does not tap-splice at all — `store.new.kz` mints one
`__store_watch_<s>_<f>_<ord>` event per arm, and the impl flow's head is
the arm's own call. Provenance lands on a cloned stamp of that head, so
the walk sees the site once `impl_of` flows are descended (they emit
through their event; the emitter's skip is only its standalone-flow
enumeration). The stamp answers why the site exists; the head's own
std-qualified name still answers what it emits — both are asked.

Evolved on the builtin-solver rung: `builtin(c)` rows stopped being
`"lowered"` statuses and became claims with three shapes — a `{1}`/`{2}`
template *is* the declared lowering, a `rule:<arm>` value names an
emitter-owned rule the catalog explicitly delegates, and `"refused"` is
the boundary as data. The emitter asks the catalog first
(`diag.resolve_builtin`) and applies the template verbatim; a template is
pinned by dual-answer — the emitter still runs the legacy arm into
scratch and drift-logs any byte mismatch, so the row cannot diverge
from the oracle it replaced without leaving an artifact. Unrowed
builtins still hit the arms unchanged; an absent catalog disables the
whole consult. The delegation shape matters: `rule:as` declares *that* an
arm owns `@as`, not *what* it emits — bounds checks stay semantic, not
spelling.

The `prelude(c)` family then took the same shape one level up: `defs`
rows carry the emitted text verbatim and the object walk is
insertion-ordered, so declared order IS emit order — the catalog is the
preamble's sole source (the literal stays only as the absent-catalog
fallback, verified byte-identical). A `"minted"` value is the third
shape: declared coverage with no fixed text, for the
`__koru_*_<store>` helper families parameterized by names the catalog
cannot know. Text and coverage are different claim kinds and the row
says which it makes.

The walk then grew a write stage on the same discipline: `std/emit`'s
`writeEventDecl` owns the agnostic part of a declaration — the
`declShape` classification (stub | wildcard | branched | plain), the
field iteration, the shape sequencing — while a `CDeclWriter` answers
the C spellings (types, member names, mangled paths). Same pin
shape as the templates: the oracle renders into scratch beside the
walk's bytes, a mismatch is drift, the oracle wins. What moved is the
*sequencing* — the questions the emitter asks — not the answers. That
is the migration's real unit: an emitter is a set of answers behind
slots, and the walk owns the asking.

The tagged-result decl was the test of that claim: what looked like
lane-owned grammar was sequencing plus three spelling answers —
`enum`/`_res` text moved into the walk with the payload rules (wildcard
hole, `__type_ref` unwrap, mixed-payload refusal) intact, and the
writer slot collapsed to `typeOf`/`memberName`/`manglePath`. When a
slot turns out to hold only sequencing, the honest move is to delete
the slot, not template it.

The event *definition* path then corrected a lazy assumption: the def
check order is not `declShape`'s — effect events return before the
wildcard check (a `!` event emits no function at all, and missing `|c`
proc is `NoCProcBody`, not a decl refusal), and body availability, not
declared shape, drives the path. The impl-resolution cascade
(`|c` proc > immediate `->` > exactly-one subflow > refuse) is agnostic
sequencing over lane-owned lookups, so the writer gained a second slot
kind: not a spelling answer but an *operation* that answers "does this
impl path exist" and renders it when it does (`renderImplFlow` rides
the oracle's `!=1` impls refusal through anyerror). And the rung
measured a subtler requirement of dual-answer itself: the oracle's
render is not a pure function of the event — it mints `__koru_res_N`
off `res_counter`, so the walk compared against a counter the oracle
had already advanced and "drifted" on `res_1` vs `res_2` alone.
Dual-answer is state isolation, not byte compare: snapshot the minting
state, render both against it, keep the oracle's end state for
downstream emission. `cur_event` is the same lesson one level deeper:
render *context* is state too — a record produce reads the enclosing
event off the emitter, so the body slots set and restore it around the
render, or `mk-reading -> { … }` refuses `UnsupportedConstruct` where
the oracle emits `struct Reading`.

The driver rung closed the lane: `writeDriver` owns the runnable-flow
enumeration (impl flows emit through their event, `declaration`/`norun`
are not run bodies, `koru.` heads are compiler-internal, only the main
module drives `main`) and the call order; the writer answers a
whole-render operation (`renderFlow`), the flow-fn name, and `main`'s
runtime-state prologue text. Extracting the shared splice cascade
(`emitSplicedFlowBody`, parameterized by in_flow/in_impl) collapsed the
emitFlow/emitImplFlowBody twin outright — the migration's own fold,
not a sanctioned twin awaiting sole-source. Events are walk-owned end
to end: preamble (catalog sole-source) → decls → defs → driver, each
still drift-pinned to the oracle it displaced.

The flip closed the arc: the walk no longer renders beside the oracle —
it renders *into* the emitted buffer, and its refusal is the lane's
refusal. The oracle survives only as emit_audit's scratch render
(renderIsolated snapshots and discards its minting state), its bytes
compared after the fact, its diagnostics still firing so a walk refusal
carries the oracle's wording. Three rules the flip made load-bearing:
the audit is a sidecar that must never gate output or mutate live state;
a writer slot can carry a *side effect* (bindField registers
int_bindings on the real render — an audit render cannot be
load-bearing); and sole-source does not collapse the migration twins —
the audit calls ARE the residual twin class, deleting only when the
oracle renderers are deleted outright. The honest next cut is per-pass:
delete an oracle renderer only after its walk pass is measured clean
across the regression set, and the audit module shrinks with it.

The emit.kz port taught the reachability rule that governs the whole
idiom: a koru_std module lands in backend_output.koru_std only when the
pipeline *invokes* one of its comptime-marked tors — `~import` makes a
module resolvable, never emittable, and `[comptime]` is the per-tor gate
that puts its handler in the generated file (an unmarked `~pub tor`
parses, accepts calls, and silently emits no event struct). With that
gate understood, the C lane became a pipeline arm exactly the way
compiler.materialize.kz does it upstream: `target-of` yields the compile
target's tag, the `| c |>` arm calls `std/emit:emit-c`, and the tor's
|zig body is the lane entry — the engine stays src/c_emitter.zig +
src/emit_walk.zig the way emit-zig's engine stays visitor_emitter.zig.
A .kz module holding the lane's address while src/ holds its engine is
not a smell then; it is the shape every lane takes as it metacircular-
izes. What belongs in emit.kz going forward is the *addressable* layer —
target routing, artifact verbs, walk tors the pipeline must call — not a
verbatim transplant of the engine's Zig.

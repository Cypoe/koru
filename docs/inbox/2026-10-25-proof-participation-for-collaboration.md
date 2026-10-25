# Proof participation in Koru — a working paper for collaboration

*Purpose: shared vocabulary between two language teams. One side (Koru) has a
language whose shape makes certain proof architectures unusually cheap; the
other side is formally trained but has not seen the language's internals. This
document tries to hand over both halves: what Koru already is, what the
verification machinery already does, and where a law-proving layer would sit.*

*Status: discussion draft. Everything marked "exists" is pinned to the `ccomp`
branch of korulang/koru unless noted; everything marked "proposed" does not
exist.*

---

## 1. What Koru is, in the vocabulary you already have

Koru is a compiled language whose unit of computation is the **tor**: a typed
dispatch node with named, typed residue arms (`| success tx | failed string |
not-found`). Flows chain tors; each arm is a transition case. The elaborated
program is a *typed control-flow graph* — and this is the load-bearing fact:
the transition system a program denotes is *syntactic*, walkable, and
completely enumerable, not reconstructed by analysis.

Computation splits into two regions with a hard seam:

- **The graph** — tors, arms, guards, cells, bindings, stores, comprehension
  stages. All program logic lives here, by discipline and increasingly by
  enforcement.
- **Procs** — host-substrate bodies (Zig today) that implement primitives.
  Under the current discipline a proc is a *thin effect shell*: IO, syscall,
  FFI, a hash. Business logic in a proc is treated as misplaced code, and the
  codebase is mid-migration moving it into pure-Koru impls.

For a verification reader: the graph is the *description of the computation*,
procs are *the interpreters of primitive effects*. The graph is where proofs
live; the proc seam is the input alphabet / environment boundary, and it is
*typed* — the arm vocabulary of an impure tor declares every shape the
environment may return.

Koru deliberately lacks l-values, pointer construction, general assignment,
and surface iterators. State lives in declared cells, bindings, stores, and
channels; mutation is mediated by typed transition points, not ambient writes.
Consequence: a koru module can *enumerate its own seams* — its tors are its
entire effect surface — which is impossible in a language where any pointer
write anywhere could be an effect.

## 2. The verification endeavor already landed (the `ccomp` branch)

A four-layer trust pyramid; each layer certifies a different relation, none
substitutes for another:

| Layer | Oracle | What it certifies |
|---|---|---|
| K1 | **CompCert** on emitted C | Koru emits a CompCert-dialect C (`output_emitted.c`) from the same elaborated flow graph the Zig backend consumes. `ccomp` compiles it; the two lanes' stdout bytes are diffed. The C is incidental — it is the input format of the only compiler carrying a machine-checked binary-level theorem. A named refusal table (`C_REFUSES`) marks the out-of-fragment constructs: host lines, `!` effect arms, concurrency. Missing oracle = FAIL, never SKIP. |
| K2 | **Alive2** translation validation | Per-instance optimization congruence on the emitted C (clang -O0 reference IR → `alive-tv`). Verdict discipline is strict; scope exclusions are named and counted. A second use — transform accounting — commits `transform-app` witness lines: each whole-program rewrite's site digest plus `rm=`/`add=` item-multiset diffs, bounded by declared `contract:preserves`/`contract:obliges`, re-decided by the Lean oracle. |
| K3 | **Lean checkers** over committed evidence | `verify/witness/WitnessCheck.lean`, `verify/holds/HoldsCheck.lean`, `verify/semantics/FlowCheck.lean` + `FlowKernel.lean`. The pipeline commits evidence *lines* (witness sites, custody edges, pass-graph arcs, `[flow-eval]` claims); the Lean legs re-decide every line rather than trusting the verdict it carries. FlowKernel is a mechanized model of the comptime walker, sound+complete against the wire format where proven (`checkLine`). |
| K4 | **Attested receipts** | `scripts/attest.py` runs the pinned battery and writes a signed receipt — tree hash, tool digests, per-gate verdicts, `proof: null` reserved for a future zk channel. `--re-run` re-executes rather than trusting recorded verdicts: re-decide, don't trust, applied to the top layer too. |

Two doctrines organize all of it:

- **Solver ≠ checker.** The producer of a claim is untrusted however good it
  is; a verdict counts only when an independent checker re-decides it. The
  in-pipeline solvers (auto-discharge insertion, transform write-backs) mint
  evidence; the checkers own verdicts; Lean is the external oracle.
- **Evidence, not narration.** What the compiler *decided* is committed as
  data — a corpus of typed lines with a closed vocabulary — so the oracle
  re-decides claims, never reads prose. A checker that accepts a forged line
  is a red battery; forged/drift corpora are standing gates.

A worked instance of the pattern: the runtime custody ledger. A bridge
(`bridge.custody.kz`) writes `holds.log` — one line per custody event
(`session-open`, `session-closed`, `mint`, `use`, `release` with
session/handle ids). `HoldsCheck.lean` re-decides whether the log is a lawful
ledger: no use or release on a non-live handle, no double-mint, session close
only when empty, no span left open. A `.kz` custody reader re-decides the same
log *in-band* — two readers, one verdict vocabulary. Enforcement is the source
of truth; the log is evidence; evidence is re-decided, not trusted.

## 3. The external comparison: gdp-wired

[gdp-wired](https://github.com/monotykamary/gdp-wired) is an automatic prover
for stateful rules in TypeScript: you declare a state machine
(params/inputs/state + a step function) and laws (invariants, step laws,
k-step laws, histories, liveness, refinement); an untrusted prover finds proof
trees, a small trusted kernel checks them, a Lean twin re-checks them, and a
search finds concrete counterexample traces for false laws. Its decidable
fragment: linear arithmetic over nat/int/rat, maps, lists, bounded quantifiers;
named refusals past it. Architecturally it is the same pattern as K3 —
untrusted producer, trusted kernel, Lean twin, falsifier — pointed at
user-authored state machines instead of a compiler pipeline.

### What we measured (spike, 2026-10-25, /tmp/gdp-spike)

We modeled HoldsCheck's actual transition rules as a gdp-wired rule, single-
and multi-session, and ran it:

- **Honest models: all laws proven, kernel accepts** — 6 laws + 3 step laws,
  including the per-key conservation `live(h) + released(h) = minted(h)` and
  counter fidelity `liveN = Σ live cells` (exact, via `Live.sum()`).
- **Every named failure mode falsified by a concrete trace**: release without
  live-check → `[open, release]` (release-of-unminted); use without live-check
  → `[open, use]` (use on dead handle); close without empty-check →
  `[open, mint, close]` (died-holding); reopen allowed → `[open, close, open]`
  (session both open and closed).

Boundaries found, measured not guessed:

- **No per-slice aggregates.** `LiveN[s] = #{live cells in s}` is
  inexpressible — single-cell laws aren't inductive. The workaround is a
  bounded-slice quantified flag (`everyBelow(B, j => Live[s·B+j] = 0)`) —
  `k + e` is the largest bound-key form the kernel's breakpoint machinery
  admits; `f(k)` on a bound key is refused.
- **Provable ≠ searchable.** The closed-empty law only inducts in two-key
  slice form; the single-key `sess(k)` form sticks the prover but is the only
  one `search()` can evaluate (it binds only the first forall key).
- **Prover cost on broken variants** ran >5 min with no verdict; the search
  found the break instantly. Falsifier-first ordering matters — for a broken
  thing, the search is the oracle.

### The honest mapping

gdp-wired certifies a *model*; it cannot certify an *artifact* — its emitted
JS is unverified codegen, no better positioned than koru's Zig emission. So it
replaces nothing in K1/K2/K4. Where it lands in koru's direction: as a
falsification rig for protocol design (cheap counterexamples before encoding
invariants in the Lean checkers), and as the reference design for a
law-proving surface — should one exist.

## 4. Prove vs simulate vs test — one quantifier

The three differ only in what they claim about the set of runs of the same
transition system:

| | Question | Quantifier | koru today | gdp-wired |
|---|---|---|---|---|
| Test | Does *this* run do the right thing? | one point | `test(...)` + mock | interpreter/compiled JS |
| Search | Is there a run within depth *d* that breaks the law? | ∃, bounded | forged/drift corpora (evidence lines only) | `search()` |
| Prove | Does the law hold for every run, every length? | ∀, unbounded | Lean legs re-decide committed *verdicts* (not runs) | prover → kernel → Lean twin |

Two asymmetries: a found run *proves* a law false (existential witness), but
no found run never proves it true (depth bound). And a proof is not a stronger
simulation — it is a certificate (induction: base + step), mechanically
checked, discharging infinite runs in finite work.

Koru already has the pieces of a law-prover scattered across subsystems; the
rest of this document maps them.

## 5. Why Koru is structurally different — the inversion

General-language proof tooling fights the language: a decidable fragment must
be carved out of unrestricted mutation, aliasing, and control flow, and the
fence costs most of the surface. Koru's restrictions flip the ratio — the
language was pre-restricted, so the fragment and the language nearly coincide.
Concretely:

**The graph is walkable and the walker is mechanized.** The comptime
evaluator (`src/comptime_eval.zig`) already walks flows concretely;
`FlowKernel.lean` is its mechanized model. A law engine quantifies over that
semantics — the substrate a prover needs already exists, audited clause by
clause.

**The environment seam is enumerable and typed.** `std/testing`'s mock
machinery already walks the graph and *requires* every impure tor to be bound
— "unmocked impure tor = error" is literally the closed-system completeness
condition a prover needs: no unnamed influence. A mock is an impl
substitution — `findImplByPath` accepts immediate values *or full flow bodies*
— so a mock is a co-machine (stateful fake-DB, adversarial scheduler), not a
constant. Bound mocks + SUT = one closed transition system; the claim then
reads "under this environment model," which is auditable code, not an
implicit alphabet. Free inputs (gdp-wired's alphabet) are the maximally
adversarial mock; realistic mocks can make proofs *easier* by shrinking case
space.

**The comprehension arm is a fenced relational step-spec.** The `! each`
arm head parses as `BINDING (when EXPR | { FIELDS })*` — filter, projection,
rebind stages in text order, fused emission (a `when` is a guard; a `{ }` is
one const per name — no intermediate collection). In prover vocabulary: `when`
before a projection is the *antecedent*; `{ FIELDS }` is a *frame condition
declared in syntax* (post-stage, only the listed names exist — the frame
problem solved at the grammar level); `! else` chains are *case splits spelled
in the glyph*; `! each` is the per-element quantifier. Doubled stages refuse
with teaching errors — the grammar itself enforces the fragment boundary.

**`std/refine` is a claims vocabulary, per-value class.** Facets declare
constraints on proto fields (`port: i64 & >1024 & <=65535`, `clamp`,
`==x`, `*1|2|3` alts); meets fold confluently across modules into typed
`facet_decl` nodes; empty meets refuse (KORU205); consumers (store insert,
list push, json decode) emit `?!violated` guards at their boundaries. This is
already the honest split a law layer wants: decidable-at-comptime → refusal;
data-dependent → boundary guard; undeclared → documentation. The meet itself
is a tiny decision procedure over integer linear facts — the same theory
class as the decidable kernel.

**`std/taps` is a transition-matching surface.** `tap(src -> dst)` patterns
(concrete, `*`, `module:*`) find production points by graph analysis and
splice observers; `when` clauses predicate on produced values; the transform
is `whole_program` with declared blast-radius contracts and witness lines.
`src -> dst` *is* a transition specifier — the placement vocabulary a
transition-law layer would need, already implemented and oracle-checked.

**Evidence is a first-class channel.** Everything the pipeline decides is
committed as re-decidable lines — custody edges, witness sites, transform-app
digests, pass-graph arcs, `[flow-eval]` claims — and Lean legs re-decide.
"One surface they all commute over" is already a convention, not a proposal.

**Post-hoc verification at unprovable boundaries.** Where a priori proof
can't reach (what really crossed the environment seam), the `holds.log`
pattern writes runtime evidence and an external checker re-decides the trace.
Bend+Raylib can do none of contract/model/evidence; koru does all three.

## 6. What is missing — the honest gap list

1. **A law surface for relational/transition claims.** Per-value claims exist
   (facets). Per-transition claims do not. Strongest candidate spelling: the
   tap match grammar (`src -> dst` + `when` predicate) with a verdict instead
   of a side effect — `require(...)` atoms riding transition patterns. Needs:
   verdict semantics (proven → free; undecidable → injected guard;
   contradictory → refusal), ghost state between fires for relational claims
   ("balance only goes down" needs a fold, not a call), and a judgment point
   (per-fire vs at-close).
2. **The decidable fence over the graph's term language.** Smaller than in
   any general language — host code is excluded by the proc seam already —
   but still must be named: which arm predicates, comprehension stages,
   facets, and cell shapes the decider may read. Same `C_REFUSES` discipline:
   refuse by name, never silently approximate.
3. **The symbolic decider.** Everything koru has today is a *concrete*
   evaluator (walker runs one path; FlowKernel models one walk). Induction
   needs a symbolic evaluator over the fragment — base + step checking with
   decidable leaves (case splits + linear refutation is the proven shape).
   Plus the strengthening wall: wanted invariants are often not inductive;
   gdp-wired needed three extra layers (`discover`, `inferLaws`,
   `findCycles`) past its kernel for exactly this. "One-loop prover" is
   achievable for the linear core; past it, synthesize or refuse — refusal is
   the boundary, not failure.
4. **Mock, widened.** Impl substitution is already a graph rewrite; the
   spelling is test-scoped. A `bind`-shaped surface usable by test, fuzz, and
   proof consumers alike makes the environment seam one mechanism with N
   consumers — "commute" made literal.
5. **Module proof participation.** Proposed role, parallel to explainer
   participation: each module declares its claims + how each discharges
   (decidable layer | residue guard | named trusted base), in a closed atom
   vocabulary (`at-most-once`, `capacity-preserving`, `settles-once`) that
   grows deliberately. `contract:preserves`/`contract:obliges` is the
   prototype at transform level; semantic participation is that pattern at
   module level. The three roles stack into one contract: **explain says what
   the module decided; witness says what it did; proof says what it
   guarantees.**
6. **The `[flow-eval]` emission leg.** FlowKernel consumes hand-authored
   corpora; koruc doesn't emit real walks as evidence yet. Laws over runs are
   dead until the emission lands — sequence: emit evidence → law surface →
   decider.

## 7. What proof cannot reach, by design

- **The proc substrate.** Zig has no mechanized semantics; host lines are
  fenced as trusted base (thin, enumerated, boundary-checked). Nobody proves
  their substrate — Bend doesn't prove its C runtime either; the mature
  answer is minimize + contract + audit, which is what the arm-typed seam,
  mocks, and `holds.log` respectively provide.
- **Environment fidelity.** A proof over SUT+mock speaks for "runs under this
  environment model." The model is auditable code, which makes the claim
  honest — but it is a claim about the closed system, not the world.
- **The fragment's outside.** Nonlinear arithmetic, arbitrary host-shaped
  computation inside a law's reach → named refusal, or an injected runtime
  guard on the `?!violated` path. The residue is where unproven claims still
  guard — fail loud, never silently verified.

## 8. Where your read would change the design

- Whether the environment-as-co-machine composition (mock folded into the
  machine) is the right formal frame for the ∀ tier, or whether free
  inputs + assumptions are cleaner.
- Whether ghost-state folds over arms are the right encoding for relational
  claims, or whether the law surface should state `before`/`after` scoping
  directly.
- What the minimal fragment exposed by the walker semantics should be —
  linear integer + maps + bounded quantifiers is the proven shape; the
  question is which additional arm/comprehension constructs can be decided
  cheaply enough to include.
- Whether "module proof participation" as a closed claim-atom vocabulary is
  the right level of obligation, or whether modules should carry richer
  spec/logic surfaces.

## Appendix — vocabulary map

| Koru | Verification |
|---|---|
| tor with typed arms | typed dispatch / transition node |
| residue arm | transition case / branch |
| flow graph | transition system (syntactic) |
| impure tor | environment seam / input alphabet |
| mock impl | environment model; closed-system binding |
| proc | uninterpreted function / trusted base |
| refine facet | declared refinement constraint (per-value) |
| tap pattern (`src -> dst`) | transition specifier |
| comprehension arm (`! each when { }`) | fenced relational step (antecedent + frame + case split) |
| comptime transform | program rewrite (untrusted producer) |
| witness/custody/pass-graph lines | committed evidence corpus |
| explainer | same-fold re-derivation mirror |
| holds.log | runtime evidence log, externally re-decided |
| `?!violated` | boundary guard / refusal path |
| `C_REFUSES`, `KORU*` | named refusals (scope honesty) |

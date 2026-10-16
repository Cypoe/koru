# koru-verification audit — what the ccomp branch proves, what it does not, and where it grows

Audit of `ccomp` / `ccomp-wsl` through `1d8b6c2d8` (59 commits ahead of
the branch point; ~465 files, +14,216/−1,821 vs `origin/main`, which has
itself moved 12 commits — see §7). Companion to `koru-verification-path.md`
(the design), `koru-verification-gaps.md` (the per-layer ledger), and
`verify-path-handoff.md` (the Lars handoff). This document is the
branch-level read: accomplishments, bugs caught by building the walls,
honest failures, and growth paths toward a formally verified Koru —
including where program-validity theorem proving and linear/dependent
typing could enter, and how much of that can start as a library or
dialect rather than core-language change.

## 1. What the branch set out to do

Koru compiles through elaborated flow graphs into per-backend emitters.
Nothing about that pipeline was independently checked: the emitters
could drift from the semantics the elaborator intends, transforms could
mutate programs with no declared bound, and CI could report success on
a battery that never ran. The branch builds a four-layer verification
battery where each layer is an *independent oracle* — a checker that
re-decides rather than trusts:

- **K1** — CompCert validates emitted C (semantic realization of the
  shared flow graph)
- **K2** — translation validation: alive2-style IR congruence (A) and
  whole-program transform accounting (B)
- **K3** — a Lean kernel re-checks witness verdicts the compiler emits
- **K4** — a signed receipt attests the pinned battery executed

The design principle throughout: *Koru holds itself upright; the
emitters carry their own obligations.* No second source semantics was
introduced — the C emitter translates the same elaborated graph the
zig emitter consumes, which is what makes byte-diff + ccomp a valid
drift oracle.

## 2. What it accomplished

### K1 — the C lane (the deepest lane)

- A full C emitter translating the elaborated flow graph — same
  semantics, second target.
- Width-correct integer lowering, `stored-write-numeric` witness kinds,
  custody-edge witnesses (compound `-> expr` returns cannot silently
  lose live obligations; `?` proto rules stay `MALFORMED` rather than
  guessing when a binding record is missing).
- **ccomp as oracle**: emitted C is compiled by CompCert's formally
  verified compiler and byte-compared — emitter drift surfaces as an
  independent refusal, not a test author's opinion.
- Eight pinned C-lane refusal classes: watches, interceptors, rules,
  and several typed/ref/owned/tree surfaces refuse by name rather than
  emitting plausible-looking wrong code. Refusals are the lane's
  honesty boundary.
- ABI-aware backend cache keys — a stale-binary hazard class closed.

### K2 — translation validation

- **Use A:** the alive2 leg exists as the documented IR-congruence
  channel (intra-procedural; see gaps).
- **Use B:** `transform-app` witness lines — every transform
  application commits its whole-program digest diff (`rm`/`add` sets)
  under `std/witness:enforce`. This is *digest honesty*: the corpus
  proves the transform touched exactly what it touched, not that the
  rewrite was semantically right.
- **`preserves` bounds**: transforms declare which `ast.Item` kinds
  they may not touch; `!kind` atoms ("all except these") keep the
  bound closed under vocabulary growth. KORU181 enforces inside the
  backend run — unconditionally, not gated on `enforce` — and the
  Lean oracle re-decides compliance from the committed line.

### K3 — the Lean oracle

`verify/witness/WitnessCheck.lean` is a standalone kernel-checked
re-decider. It does not trust the compiler's verdicts; it parses the
committed corpus and re-decides every shape: custody edges, descriptor
scopes, transform-app balances and preserves bounds, and the pass-graph
linearization. The corpus regime has three honest controls:

- `golden.txt` — what a real corpus looks like (41 lines, 0 bad)
- `forged.txt` — 56 per-line malformed shapes, every one rejected
- `drift.txt` — per-line-valid but corpus-dishonest (reversed orders,
  honest-but-violating census counts), rejected by corpus-level checks
- an empty corpus is a *failure*, not a pass — silence is not success

### The declared pass graph (rungs 1–4)

- `[requires("a","b")]` on tors — declarer-side ordering edges (the
  `depends_on` grammar slot), checked at pipeline-bake time. KORU180
  refuses four shapes: order violation, unknown name, cycle, and
  required-never-runs-at-root.
- `[requires]`/`[preserves]` on `[transform]` decls — intra-transform
  ordering satisfiable only across stages (`pre` < `main` < `post`),
  since the fixed point's first-found walk order is no declarable
  contract.
- The hand-authored order stays authoritative — the graph *validates*,
  never reorders. A checker that could reorder would be a second
  scheduler.
- Rung 3 commits the arcs: `pass-graph-{edge,order,tedge,tstage,census}`
  witness lines baked into the generated backend; Lean re-decides the
  linearization, stage ordering, and census completeness independently.
- Rung 4 is process: the `[requires]` vs `std/compiler:requires`
  spelling collision is recorded for Lars (options table in the
  handoff; shipped `requires` as executive decision, rename is
  mechanical), and the gaps ledger exists.

### K4 — attested receipts (rung 1)

- `scripts/attest.py emit` runs the pinned battery and writes a signed
  `koru-attest/1` receipt into `receipts/`: tree hash, `tree_dirty`
  honestly, koruc/ccomp/lean digests, corpus and gate-script digests,
  per-gate verdicts, host ABI (`uname`/`ldd`), `proof: null`.
- Ed25519 signed; the signer is a `did:key` and `tools/attest.pub`
  pins *which* did counts — a valid signature from an unpinned key is
  a signature, not an attestation.
- `verify` checks three claims separately — signature valid, signer
  trusted, digests match — because each fails differently (verified:
  tampered verdict → INVALID + REJECTED).

## 3. What building the walls caught

The strongest evidence the layers are real is what they refused:

- **`collect` never recursed into `module_decl`** — rung 1's seeded
  `compiler.kz` edges were parsed but validated by *nobody* for a
  whole rung. A checker that never reads the decls it guards is prose
  wearing a wall's clothes. Verified by injecting a bogus nested edge:
  it refused after the fix.
- **Cross-surface misread** — a transform invoked at a root flow had
  its intra-transform `requires` re-checked as a pipeline edge → false
  "root pipeline never runs" refusal. Fixed; the converse (pipeline
  tor requiring a transform) refuses by name.
- **`catch break` witness truncation** — arc emission could silently
  drop a line while the census claimed the full count. Now propagates:
  the compiler refuses rather than emitting a corpus it cannot
  honestly count.
- **ABI-blind backend cache** — same-content binaries were keyed
  without the target ABI.
- **The environment is part of the trusted base** — putting elan's
  toolchain dir on PATH shadows `cc`/`clang`/`ld.lld`; `zig build`
  then links a glibc-2.34 `Scrt1.o`, producing binaries unrunnable on
  the 2.31 host. The oracle invocation perturbed the satisfier it was
  verifying. `KORU_LEAN` exists for exactly this.

## 4. What it did not do — honest failures

- **Nothing here is end-to-end verified — but nothing is vacuous
  either.** Each layer's check is a real proof of a real proposition:
  a Lean re-decision is kernel-checked, a ccomp leg is a verified
  compilation. What is unverified is the *composition* — no link
  proves graph→C→asm preserves semantics as a chain. The seam is
  open; the propositions on either side of it are not. Vacuity would
  enter through coverage, which is exactly what the forged corpus,
  census, and collect-recursion machinery exists to guard.
- **K2-B is accounting, not congruence — with a sharper residual than
  first stated.** Digest sets make *mutation of a preserved kind*
  caught, not merely bounded: a changed preserved item must appear in
  `rm`/`add` with a forbidden kind, so KORU181 fires. What remains
  unchecked is correctness *within* permitted kinds — a transform may
  rewrite the kinds it owns and nothing decides the rewrite was
  semantically right. Call this an **obligation gap**, not a bound
  hole: the bound is satisfied — it is the obligation that does not
  exist. Nothing requires the transform to justify a permitted touch.
  This is the taxonomy the audit runs on: coverage gaps (arcs never
  printed), bound gaps (surfaces never bounded), and obligation gaps
  (touches never justified). The `[transform|obliges(...)]` rung
  (§6b) now closes the first two decidable instances —
  `kind-stable` (collateral kind multisets agree) and `matched-only`
  (every removed non-site item contains a matching invocation) —
  enforced unconditionally at apply time (KORU182) and re-decided
  by the Lean oracle from `transform-oblige` evidence. The open
  remainder is the deep one: no declared obligation yet says the
  rewrite preserves *meaning* — that is the semantic-obligation
  surface §6a's Lean kernel exists to make expressible.
- **K3 sees only printed arcs.** An unprinted obligation, an unemitted
  edge, a silent skip — invisible to the oracle. Corpus completeness
  rests on the compiler's wire between `validate()` and the printed
  lines: the emitter and the oracle enumerate the same arc set by
  convention, not by construction (the zig validator and the Lean
  rules are two hand-written enumerations that can diverge).
- **The pass graph is opt-in and order-only.** Undeclared orderings
  are unchecked; requires/preserves say nothing about data flow,
  termination, or semantics.
- **K4 rung 1 is self-attestation — now shrinkable to provenance.**
  `verify --re-run` re-executes the battery and compares verdicts, so
  the verifier re-decides rather than trusting recorded outcomes; the
  receipt degrades gracefully to "the pinned attester claims these
  inputs were tested" for readers who do not re-run. `proof: null`
  remains reserved for the zk leg that removes attester honesty from
  the trust base entirely.
- **The battery is one gate.** `witness_gate.sh` only — the regression
  suite, ccomp legs, and alive2 legs are outside the attested set.
- **The attester key lives on one host** — attestations cannot yet be
  issued from anywhere else (which is also the pin working correctly).
- **Known residual wrongness carried, not fixed:** `usize -> i64` is
  deferred rather than refused; the cs emitter's culture-sensitive
  `f64.ToString`; `330_060`'s pre-existing wrong-error expectation;
  env-split checks (dotnet/node absent on WSL).

## 5. Where the gaps live structurally

Two axes audit the ledger, and they are orthogonal — a gap needs both
coordinates to be closed. **Kind of gap:** coverage (an arc the
emitter never prints — invisible to every oracle), bound (a surface
nothing constrains — the transform may touch it freely), obligation
(a permitted touch nothing requires to be justified). **Seam:**
the three below. A check that closes coverage on one seam can still
leave the obligation gap open on the same seam — rung-3's pass-graph
lines have complete coverage and zero obligation content.

1. **The emitter-trust seam** — everything Lean checks arrives through
   the compiler's own print statements. Closing it needs either (a) a
   second, independently-written extractor reading the same flow graph
   and emitting the arcs — drift between the two emitters is itself
   the check; or (b) proof-producing emission (§6).
2. **The elaborator** — the single source semantics is unverified.
   K1's ccomp oracle validates C *given* a correct graph; nothing
   checks the graph against Koru's surface semantics. This is the
   largest unverified span.
3. **The environment** — host ABI, toolchain PATH, cache keys are all
   trusted. K4 receipts pin them; only a zk/guest execution removes
   host trust, and even then the receipt pins what the guest ran.

## 6. Growth paths

### 6a. Toward formally verified Koru (compiler correctness)

The CompCert shape is the honest template: a mechanized semantics for
the source, a mechanized semantics for the target, and a proof that
translation preserves it. This is the next rung — *scoped, not total*:
do not mechanize Koru's semantics, mechanize a kernel subset of the
flow graph (values, arithmetic, calls, branches — the shape a small
fixture family exercises). Weeks-scale, not years; and it anchors the
existing propositions to meaning rather than digests.

- **Rung A — mechanize a kernel flow-graph semantics in Lean.**
  *Landed:* `verify/semantics/FlowKernel.lean` is a mechanized model of
  `comptime_eval.zig`'s walker — values (int/float/bool/str/array/
  cell), the full binary/unary operator set (truncating `/`,`%`,
  floored `@mod`, `++` concat, short-circuit `and`/`or`), lazy
  conditionals and builtins (`@as` evaluates only its value argument —
  the type name is never evaluated), field access, bounds-checked array
  indexing, tagged/bare/void dispatch (void results refuse at every arm
  site; catchalls participate in bare dispatch only), `#label`+`@jump`
  loops, named args, and thunk oracle leaves. `run` is fuel-bounded;
  `run_mono` proves more fuel never flips a decided result. ~45
  `native_decide` fixture theorems pin the distinguishing surface —
  including void-dispatch refusal, guard order, payload-before-guard,
  nested invoke continuations, env isolation, and unasserted-thunk
  refusal. Faithfulness was established by clause-by-clause audit
  against `comptime_eval.zig`, which caught and fixed seven model-side
  divergences (the walker was right every time; the model is now the
  side that had to move). *Corpus surface landed:*
  `verify/semantics/FlowCheck.lean` consumes `[flow-eval]` s-expression
  claims — whole-program graph + entry call + fuel + asserted result +
  asserted thunk oracle leaves — and re-decides each through `eval`;
  `refuse` claims succeed only when the kernel actually decides
  `none`. Golden/forged/drift corpora are gated by
  `scripts/semantics_gate.sh`, which the attested battery runs and
  whose digest the receipt pins. **Open:** nothing *emits* claims yet —
  koruc-side serialization of kernel-subset walks on real corpus runs
  is the remaining leg, and until it lands silent divergence between
  kernel and compiler is possible in both directions (that is the
  point of a single mechanized definition; emission is what exercises
  it). Effects, stores, `|*`, taps, transforms, modules, name
  resolution, recursion, function calls, fragments, destructured arms,
  `Source` args, non-enclosing labels, and i64 overflow (the kernel
  uses unbounded `Int`) are declared refusals.
- **Rung A.5 — per-instance refinement, subset-declared.** With the
  evaluator, a Lean checker takes graph + emitted C for a kernel
  program and verifies refinement *for that program* (the CompCert
  lesson: verified checkers beat verified generators — small, and they
  refuse loudly). For the covered subset the chain graph→C→asm then
  becomes genuinely end-to-end: Lean-checked refinement above,
  CompCert below. A `verified-subset` tier falsifies "nothing is
  end-to-end verified" for a declared region instead of waiting for
  the whole pipeline.
- **Rung B — prove emitter correspondence per-instance or once.**
  Two strategies, both honest: keep translation validation (ccomp +
  byte-diff per program — scales, never proves a universal); or prove
  the C emitter correct against the Lean graph semantics once (hard,
  closes the seam forever). The pragmatic path is per-instance now,
  mechanized-semantics later, with the corpus already shaped for it.
- **Rung C — the elaborator.** Surface → graph lowering is the last
  unverified span. A Lean-checked elaboration certificate (the graph
  is a refinement of the surface AST) is the long pole; intermediate
  value is real — witness lines already give per-node provenance.

### 6b. Theorem proving for program validity

K3 already demonstrates the pattern: the compiler emits *claims*, an
independent kernel re-decides them. Growing this into proof-carrying
programs:

- **Rung A — obligation witnesses.** First leg landed: transforms
  declare `[obliges("kind-stable","matched-only")]` — re-decidable
  claims about their own write-back — enforced unconditionally
  (KORU182) and committed as `transform-oblige` evidence the Lean
  oracle re-decides. The pattern now proven: the compiler commits a
  claim plus the evidence needed to falsify it, the oracle re-decides
  from evidence alone and refuses a dropped or extra line. Next leg:
  the compiler emits *obligations it could not discharge* — assertion
  conditions, custody invariants at boundaries — as structured claims
  Lean decides. `auto-discharge` already names the discharged side;
  the undischarged side is the proof-bearing surface. Semantic
  obligations ("this rewrite preserves evaluation") remain
  inexpressible until §6a's kernel gives them a domain.
- **Rung B — user-written proofs.** A `proof` block or attached
  certificate per obligation; the compiler forwards it, Lean checks
  it. This is PCC in the original sense — code ships with evidence a
  kernel can verify — and it lands naturally because the corpus
  plumbing, the gate, and the forged-corpus discipline already exist.
- **Rung C — dialect-level verification conditions.** VCs generated
  from requires/ensures on tors, discharged by Lean tactics or an SMT
  bridge, receipts pinned per-program.

### 6c. Linear / dependent types — library or dialect first

Koru's custody model is already proto-linear: obligations are tracked,
moves are witnessed, `custody-edge` lines prove obligations survive
compound returns. The growth question is *where* enforcement lives:

- **As a library (near-term, zero parser change):** phantom-typed
  wrappers — the codebase already has `check-phantom-semantic` as a
  pass precedent — can encode affine handles whose destructors are
  custody-checked. Limited to what the type system can express, but
  every guarantee lands as an ordinary witness line the existing
  battery already re-decides.
- **As a dialect (medium-term):** a `~linear` surface where bindings
  are use-checked affine by default, elaborating to the same flow
  graph plus discharge witnesses. The dialect boundary keeps
  conservative Koru untouched and makes the linear fragment opt-in —
  matching the branch's opt-in pass-graph discipline.
- **Dependent types (long-term):** the honest staging is refinements
  first — `i32{x > 0}`-style predicates checked as proof obligations
  through the K3 pipeline — before full dependent function types.
  Refinements reuse the entire witness infrastructure; Pi-types
  require the elaborator to carry proofs, which is exactly rung C of
  6a. The branch's receipts are the natural certificate carrier.

### 6d. K4 completion

Widen the pinned battery (regression slice, ccomp legs, alive2 legs),
multi-signer receipts, then the RISC-V guest: koruc cross-build, ccomp
port, fixture manifest — `proof` becomes a real zk receipt and the
self-attestation clause is deleted, not narrated around.

## 7. Merge/integration watch-outs vs origin/main

Main moved 12 commits: `std/compress`, backend coordination-echo
suppression, test-ID renumbering. Overlaps:

- `src/main.zig` — the real merge risk; both sides changed it
  substantially (upstream echo suppression vs pass-graph/witness work).
  Different regions, but review by hand.
- `src/errors.zig` — disjoint (`diagnostics_were_printed` vs KORU179).
- `deslop-census.baseline` — same values, different notes.
- Test IDs will shift — pins `220_*`/`310_140` renumber on merge.
- `koru_std/compress.kz` "deletion" in the diff is divergence, not
  intent — do not let a merge resolve it as a branch deletion.

## 8. The one-paragraph read

The branch did not make Koru verified — it made Koru *auditable*: every
claim the compiler now makes has an independent re-decider, a forged
control that proves the checker refuses, and a signed receipt that the
battery ran. The honest summary is that verification here means
*independent refusal surfaces*, not proofs of correctness — and that
distinction is load-bearing for everything that grows on top of it.

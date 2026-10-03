# Fuzz → proof roadmap

Ordered actionable items from the fuzzing/ISAR discussions (2026-10-01/02,
branch `fuzz-ga`). Goal: move koru's checkable surface from *empirically
fuzzed* toward *provably sound* — verified instruments where closure
theorems exist, principled search where they don't.

Regression corpus for all of it: `fuzz/repros/` (seven `-c`-green /
coordination-red findings + two obligation probes). Runtime scratch stays in
gitignored `.kfuzz/`.

## 1. Holonomic recurrence gate — V0 LANDED

`scripts/holonomic_gate.py` + fixtures `fuzz/holonomic/`. Koru `#L`/`@L`
folds whose step is polynomial-in-state get *decidable equality*:

- Extract: `tor step` params → state tuple; continue-arm `{f: e, …}` →
  transition map F; guard → loop bound; `#L step(init)` → initial state.
  Updates restricted to an arithmetic subset (+, -, *, @divTrunc, @mod,
  @as/@intCast/@intFromBool no-ops); anything else → `REFUSED: <why>`.
- Certify: undetermined-coefficients fit of `Σ p_i(n)·a_{n+i} = 0`
  (nullspace of the sample matrix — bounded order/degree search), then
  verified exactly by one of two paths:
  - closed form: all updates affine in state → `s_n = Tⁿ·s₀` via sympy
    symbolic matrix power → certificate residual is an identity in n;
  - generic-state residual: F^i over a generic state with affine
    counters pinned to `init + c·n` (catches factorial-style folds
    where the observed field is multiplicative).
- Gate: `A ≡ B` iff both sides certify (orders m_A, m_B) AND the exact
  difference trajectory vanishes on the first `m_A+m_B` iterates plus
  every index where a leading coefficient is singular. Sum-closure
  bound — the certificate names an m-dimensional solution space, so the
  initial-terms check is the required base case, not a shortcut.
- Verdicts: `CERTIFIED` / `EQUAL` / `NOT-EQUAL` (with concrete iterate
  witness) / `CANDIDATE` (fitted, unverifiable) /
  `NOT-FOUND-WITHIN-BOUNDS` / `REFUSED`. `python scripts/holonomic_gate.py
  selftest` pins 12 verdicts — including `sq_incr ≡ sq_direct`
  (sum-of-odds == squares), `sum_desc ≡ sum_desc_commuted` (the 020_028
  corpus fold vs a commuted twin — GA-style mutation proven identical,
  bound 2 + singular point n=10), and `tri_builtin` (honest CANDIDATE:
  `@divTrunc` is non-affine).
- **Measured coverage: 8/128 `#`-files CERTIFIED** (2026-10-03 rescan;
  6 fixtures + 020_028 + 320_152 — the second corpus certification comes
  from **parametric init**: `attempt(n, left: 3)` where `n` is a caller
  parameter stays symbolic; the certificate is fitted on a prime
  specialization and verified for all parameter values. Positional init
  args map to fields in declaration order.) Remaining refusals: 59×
  `#` non-fold labels, 53× non-`{f: e}` arm shapes, head/arm-payload
  bindings (`clock(passes): n |>`, `boom f =>`) — forced recurrences,
  not autonomous transitions — plus `@min`. Widening further means
  more extractor shapes; certified synthesis means a fold-*targeted*
  expression genome (mutate update arithmetic, gate supplies fitness),
  not an adapter over the construct-splice GA.
- Does **not** need the koru dialect — its encode target is
  certificates, not ITerms.
- Lean bridge — LANDED in isar-proofs (`da97bdd`,
  `src/ISAR/PRecursive.lean`): `PRecursiveCertificate` +
  `eq_of_satisfiesRecurrence_of_init` — non-singular uniqueness proven
  (strong induction, peel leading term, cancel in ℚ). The gate's bound
  is now discharged, not asserted.
- Cross-field bridge — FORWARD direction LANDED in isar-proofs
  (`d4660f0`, `src/ISAR/HolonomicBridge.lean`): `dfiniteResidual`
  (coefficient of x^N on the sequence side), `bridgePolyCoeffs`
  (translated recurrence coefficients `(X+k)↓ᵢ`), and
  `dfiniteResidual_eq_bridge` — the two residuals agree for
  N ≥ shiftBound. `satisfiesRecurrence_of_dfinite` wraps it:
  ODE satisfaction implies `PRecursiveCertificate` satisfaction
  (certificate packaging needs q_order(0) ≠ 0; the identity does not).
  Open: the converse (P-recursive ⇒ D-finite via the Euler operator,
  needs initial-term truncation), and the singular-point uniqueness
  theorem (agreement at indices where the leading coefficient
  vanishes replaces the missing constraint).
- Fuzzer tie-in — LANDED as `scripts/holonomic_synth.py`: GA over
  update-expression genomes (born in-fragment by construction), fitness
  = first-divergence index into the 64-iterate window (semantic, not
  syntactic), terminal = gate `EQUAL`. `--selftest` pins it: 3 distinct
  certified-equal mutants of `sq_direct` in ≤3 generations, including
  the incremental `acc + 2n - 1` discovered by search. Program +
  certificate, not program + hope.

## 2. Obligation-scoped mutation fuzzing — FIRST SWEEP LANDED

Move discharges across scope boundaries instead of splicing syntax:
consume-inside-`! each`, drop-before-`@`-edge, `[@scope]` add/remove,
conditional-consume join states, borrow escape into a store.

- Baselines committed: `probe_nested_obligation.kz` (ambient carry, correct)
  and `probe_nested_consume.kz` (KORU030 caught). The checker is firmer
  than its LIMITATION-1 comment feared — per-binding discharge state
  catches re-feeds; the residual holes are join-point state and aliasing.
- `scripts/obligation_fuzz.py` (run under WSL — `koruc` is an ELF and
  needs `/home/cypoe/tools/zig-0.15.1` on PATH plus the zigcache env
  vars, which the script now injects). Five semantic operators:
  `refeed-stale`, `drop-at-arg`, `double-dispatch`, `arm-end-consume`,
  `scope-toggle`. Operators mask `//` comments before matching —
  the 330 corpus documents its own fold shape in prose and an early
  run produced mutants that only edited the comment (vacuous GREENs).
- Measured (2026-10-03, 75 mutants over the 330_07x–08x family + probes):
  45 KORU030, 11 KORU100, 2 KORU022 at their expected layers — the
  coordination wall holds. 14 `scope-toggle(add)` mutants build
  end-to-end: a user-written `[@scope]` on an ordinary fold arm is
  honored (over-restriction, benign direction — but confirms the
  annotation is not loop-body-only).
- **Finding** — `fuzz/repros/probe_arm_end_consume_emit.kz`: an outcome
  arm routed to a discharger (`| again v |> done(h: v)`) passes `-c`
  AND all 20 coordination passes, then emits uncompilable Zig
  (`loop: while(true)` with no `continue` → unused label). Routing the
  same arm to a non-consumer refuses correctly (KORU022), so the
  checker tracks obligation drop but not the unproduced declared
  return — and emission emits the loop label on arm structure, not on
  whether a `continue` exists.
- Open: `scope-toggle(remove)` has no coverage — no seed carries
  `[@scope]` to remove, and removal is the dangerous direction.
  Conditional-consume join-point state and borrow-escape-into-store
  remain unprobed.

## 3. Koru dialect in isar-proofs — the general version

`koru_dialect.py` QuotientMap: encode `program.ast.json` (koruc's canonical
emitted payload — no new parser needed) → substrate ITerm; outcome
vocabularies → variant dispatch, folds → combinator recursion, obligations
→ phantom-erased (unless a regime wants them observable). `koruc`'s binary
becomes a witness under the `stdout+rc` regime; `cross_verify` gains a
limb. Turns every KORU021/022-type disagreement into a congruence question.
Lean obligation: `QuotientMapO.preserves`.

## 4. GA → observation fitness — PARTIALLY LANDED (dialect-free variant)

The dependency on item 3 was overstated for the regression variant: the
holonomic gate's own observation surface (trajectory agreement + verified
certificates) is enough — `observe(encode(x))` is needed only when the
observation must be substrate NF.

- `scripts/holonomic_regress.py` — certified *symbolic regression*:
  the target is bare iterate data, not a reference program. Fitness is
  first-divergence depth into the observed window; terminal is
  `REGRESSED` — a candidate whose certified trajectory reproduces all W
  terms, with overdetermination (W − order) reported. The certificate
  is a theorem about the program; the data-fit is honestly regression
  (finite observations admit infinitely many extensions — the verdict
  says so). Selftest: squares data → 3 certified programs in ≤2
  generations (`n*n` spellings + discovered `acc + 2n − 1`); fibonacci
  data → honest zero-match (unreachable in the single-acc fragment).
- Still parked behind item 3: the substrate-NF observation variant and
  the adversarial cross-layer-disagreement fitness (synthesize the
  KORU021/022 class). The obligation sweep already produces that class
  empirically — wiring it as *fitness* wants the dialect.

## 5. Quantity / structural arithmetic — orthogonal, cheap

`std/quantity` phantom-typed units (`f64<metre>` etc.) — the ISAR algebra
ports, the substrate isn't needed. Later: a verified-numerics variant that
delegates numeric tors through the dialect instead of Zig f64.

## 6. HoTT — parked, and correctly so

Not in Koru (no dependent types); lives in the meta layer, which is Lean
(MLTT + quotients, no native univalence). Koru's resource axis maps to
*graded* / quantitative type theory, not homotopical — if a richer
discipline ever formalizes obligations, QTT is the honest target.

## Open questions carried

- Fold-exit re-dispatch: `#L` fold whose exit arm is a bare `|>`
  continuation re-dispatches the terminal outcome forever (measured
  14.5M times) — intended semantics or defect? `-> e` is the proven exit.
- Emit placement: `koruc` has no output-dir flag; `-o` names only the
  driver while the real payload (`program.ast.json`) lands beside input.
- `Child.run` pin (400_141) still shapes any in-language test-runner.

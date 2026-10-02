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
- **Measured coverage (2026-10-02): 1/111 corpus `#`-fold files in-
  fragment.** The extractor accepts one shape — `=> br {f: e, …}` update
  records, literal-or-callsite-resolvable init, single comparison guard.
  The corpus's other folds refuse on arm shape, `for()`-library loops,
  or parametric init. Widening coverage means more extractor shapes;
  certified synthesis means a fold-*targeted* expression genome
  (mutate update arithmetic, gate supplies fitness), not an adapter
  over the construct-splice GA.
- Does **not** need the koru dialect — its encode target is
  certificates, not ITerms.
- Still missing (Lean, ideally): uniqueness-from-initial-conditions for
  P-recursive sequences stated as a theorem — the gate *implements* it;
  the Lean side would discharge the meta-justification the runtime
  currently asserts.
- Fuzzer tie-in: GA-synthesized folds feed the gate → certified
  program synthesis (program + equality certificate, not program + hope).

## 2. Obligation-scoped mutation fuzzing

Move discharges across scope boundaries instead of splicing syntax:
consume-inside-`! each`, drop-before-`@`-edge, `[@scope]` add/remove,
conditional-consume join states, borrow escape into a store.

- Baselines committed: `probe_nested_obligation.kz` (ambient carry, correct)
  and `probe_nested_consume.kz` (KORU030 caught). The checker is firmer
  than its LIMITATION-1 comment feared — per-binding discharge state
  catches re-feeds; the residual holes are join-point state and aliasing.

## 3. Koru dialect in isar-proofs — the general version

`koru_dialect.py` QuotientMap: encode `program.ast.json` (koruc's canonical
emitted payload — no new parser needed) → substrate ITerm; outcome
vocabularies → variant dispatch, folds → combinator recursion, obligations
→ phantom-erased (unless a regime wants them observable). `koruc`'s binary
becomes a witness under the `stdout+rc` regime; `cross_verify` gains a
limb. Turns every KORU021/022-type disagreement into a congruence question.
Lean obligation: `QuotientMapO.preserves`.

## 4. GA → observation fitness (depends on 3)

Rewire `fuzz/ga.k` / `composition_gp.py` fitness from uncovered-cell hits
to `observe(encode(candidate))` agreement. Adversarial variant: maximize
cross-layer disagreement (-c vs coordination vs substrate NF) — targeted
synthesis of the KORU021/022 class rather than random splicing.

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

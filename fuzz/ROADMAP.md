# Fuzz → proof roadmap

Ordered actionable items from the fuzzing/ISAR discussions (2026-10-01/02,
branch `fuzz-ga`). Goal: move koru's checkable surface from *empirically
fuzzed* toward *provably sound* — verified instruments where closure
theorems exist, principled search where they don't.

Regression corpus for all of it: `fuzz/repros/` (seven `-c`-green /
coordination-red findings + two obligation probes). Runtime scratch stays in
gitignored `.kfuzz/`.

## 1. Holonomic recurrence gate — ACTIONABLE NOW

Koru `#L`/`@L` folds whose step is P-recursive get *decidable equality*:
extract the recurrence, form the difference via the proven closure ops
(sum/product/integral — Lean-checked in `isar-proofs`, `ISAR.Holonomic*`),
then check an initial segment bounded by the difference order.

- A certificate names an m-dimensional solution space, not a point —
  the bounded initial-terms check is the required base case, not a
  shortcut. Refusal (non-P-recursive step) is first-class output, matching
  `holonomic_not_closed_under_compose`.
- Reuses `isar-proofs/scratch/isar_holonomic_closure_algebra.py` (Python
  kernel) with the Lean modules as the meta-justification. Does **not**
  need the koru dialect — its encode target is certificates, not ITerms.
- Missing piece (Lean, ideally): uniqueness-from-initial-conditions for
  P-recursive sequences — the theorem that justifies the bounded check.
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

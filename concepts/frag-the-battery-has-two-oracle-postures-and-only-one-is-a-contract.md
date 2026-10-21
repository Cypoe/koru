---
type: belief
id: frag-the-battery-has-two-oracle-postures-and-only-one-is-a-contract
provenance: 2026-10-18 — wiring K2's Alive2 leg out of opt-in surfaced that
  the battery carried two different meanings for "a marker is present": the
  c leg's marker=contract (LANGUAGES lists c ⇒ ccomp must exist or the test
  fails c-oracle) and the Lean legs' marker+env=contract (WITNESS_CHECK /
  FLOW_EVAL_CHECK / HOLDS_CHECK / C_REFINE_CHECK additionally require
  KORU_WITNESS=1; without it the leg is a noted skip by design, "machines
  without Lean"). K2 now sits in the first class.
ts: 2026-10-18
---

# The battery has two oracle postures, and only one is a contract (belief)

**Posture A — marker = contract.** The marker is the test's claim on the
oracle; the oracle's absence on the host is a FAIL naming the resolved
path. `LANGUAGES=c` + no `ccomp` → `c-oracle`; `ALIVE2_CHECK` + no
`alive-tv`/`clang` → `alive2-oracle`. Nothing is skipped; a host that
cannot answer cannot call the cell green.

**Posture B — marker + env = contract.** The marker names the *intent*;
an env flag (`KORU_WITNESS=1`) is what turns intent into claim. Without
the flag the leg is a noted skip — the witness, flow-eval, c-refine, and
holds legs all live here, and the comments say why: the oracle is an
external Lean toolchain, heavy enough that "every host that runs the
suite" and "every host that can answer" deliberately differ.

The asymmetry is *documented, not accidental* — but it is still an
asymmetry, and asymmetries in a battery whose honesty contract is
"missing oracle = FAIL, never SKIP" are where the next silent hole
grows. The honest reading of posture B is that the suite has two
verdict levels no output distinguishes: "green" and "green except the
oracle legs the host declined to arm." A `KORU_WITNESS`-less run of a
`WITNESS_CHECK` test prints a blue parenthetical and a PASS — the
parenthetical is the only place the distinction lives.

## What follows

- **K2's landing chose posture A deliberately.** clang + alive-tv are
  not lighter than Lean, so "toolchain weight" is not the real dividing
  line — the line is whether the oracle was provisioned for the lane the
  battery is exercised on. On the pinned K1/K2 lane (WSL + nix profile)
  all oracles exist; posture B's skip exists for hosts that were never
  the pinned lane.
- **Whether posture B survives is a Lars call.** Options: lean legs move
  to posture A (suite on an unprovisioned host goes red `witness-oracle`,
  same as `c-oracle` does today); or the suite prints a distinct
  "not-armed" verdict class so B stops reading as green. Both preserve
  honesty; silence is the only posture that doesn't.
- **The selfcheck pattern generalizes.** `alive2_gate.sh --selfcheck`
  fires a forged pair the gate must reject plus an honest pair it must
  accept — the gate proves it can disagree before its `correct` counts
  mean anything. Any oracle leg that counts verdicts owes the same
  demonstration; the witness gate already carries golden/forged corpora
  for exactly this reason.

## Open

- ~~Recorded in `docs/OUTSTANDING_DESIGN_DECISIONS.md` as C5: do the Lean
  legs join posture A, or does "not armed" become a named verdict?~~
  **Ruled 2026-10-21 (ccomp-line proposal, fork review pending): posture
  A.** `HoldsCheck` re-decides `holds.log` — the custody ledger's oracle —
  and an opt-in oracle on the language's center means a green run can
  certify a claim nobody checked. Migration: land a named `NOT-ARMED`
  verdict first (a skip is never green even in transition), then flip the
  Lean legs once host provisioning is scripted. `NOT-ARMED` survives as
  transition plumbing and for genuinely-optional legs — it is not a
  terminal verdict the suite can pass on.

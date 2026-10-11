# Koru Verification Path — C Emit, IR Congruence, Proof-Carrying Obligations, Attested CI

Target branch: `Cypoe/koru:ccomp` (cut from updated upstream `korulang/koru`)
Status: design note for co-review with Lars. Non-negotiables are marked **N**; shape questions are marked **S**.
Working constraints honored: bring questions, never invent spellings; regression tests first; no builds while `run_regression` is live.

---

## 0. The trust pyramid

Four layers, each certifying a different thing. No layer substitutes for another:

1. **CompCert** — the *reference compiler* is correct (their theorem, their Coq proof).
2. **Alive2** — each optimization *instance* on our code shapes was checked (bounded, SMT-backed witness — not a theorem).
3. **Verified checker** — koru's obligation *verdicts* are correct (our theorem, in Lean, small).
4. **zkVM receipt** — the battery *actually ran*, on pinned artifacts (attestation of process, not of semantics).

A proof about semantics does not attest execution. An attestation of execution does not prove semantics.
Every layer below is only as strong as the layer above it that it leans on — so each layer is pinned to the
one thing it can actually certify.

---

## 1. K1 — C emit + ccomp oracle

**Scope:** tier-1 runtime Koru, sequential, deterministic. This is a second independent realization of the
semantic space, not a replacement backend. The Zig emission stays the product path.

**Refusal table** (every entry refuses by name — silent acceptance is a red battery):

| Construct | Reason out of scope |
|---|---|
| host lines (raw Zig) | cannot lower to C |
| `!`-effect arms | resume semantics out of oracle scope |
| `pump` / `rings` / `worker.spawn` | CompCert is a sequential C subset; no verified concurrency |
| comptime/transform tors leaking runtime effects | tors vanish at compile time by definition |

**Dialect:** CompCert C subset — ISO C99 minus VLA, minus `setjmp/longjmp`, minus `long double`,
fixed-width integer types, CompCert C's defined evaluation order (use it — determinism of the reference
is part of the oracle contract).

**Lowering table:**

| Koru | CompCert C |
|---|---|
| tor | dispatch function; branches = tagged result |
| continuation arm | caller-side switch |
| binding | single-assignment local (const-initialized) |
| cell | module-scope array/struct (closed accessor set → static) |
| transform/comptime tors | nothing emitted; refuse if effects leak |

**Gates (canonical cells; missing oracle = FAIL, never SKIP):**

- **G-CC-1** equivalence: both backends, stdout bytes + rc. First program class: a finite byte transducer
  over `std/io`. Then prime-sieve parity (the existing showcase corpus).
- **G-CC-2** missing `ccomp` = FAIL naming the oracle path.
- **G-CC-3** refusal tests: every out-of-scope construct refuses with a named reason. Silent acceptance of
  any row = FAIL.
- **G-CC-4** determinism pin: pinned ccomp version + flags; same input → byte-identical binary. Gate it,
  don't assume it.

**Acceptance:** G-CC-1 green on transducer fragment and sieve; refusal table complete; no upstream syntax
invented (emitter mode + transform tor; placement questions go to Lars).

---

## 2. K2 — LLVM IR congruence (Alive2-style)

**Mechanics:** `-fllvm` build leg; `getEmittedLlvmIr()`; Alive2 translation validation (requires an
RTTI-enabled LLVM build).

**Use A — instance checking:** validate LLVM's own optimization passes on koru-emitted IR. Catches
wrong-code bugs on koru's specific shapes; generalizes Csmith-style differential results without the
UB-handling burden.

**Use B — transform congruence:** emit IR before and after a koru-level optimization transform; Alive2 as
the per-instance equivalence witness between the pair.

**Honesty clause:** Alive2 is sound up to its bounds. A PASS is a checked instance, not a theorem; record
passes as witnesses. The `-fllvm` leg is not the product binary when the self-hosted x86_64 backend is the
default — the ccomp oracle is the layer that speaks for shipped artifacts. Document the coverage map per
target, per backend, per layer.

**Gates:**

- **G-LL-1** opt-TV clean over the corpus arm.
- **G-LL-2** negative control: two IRs that genuinely differ → Alive2 must flag (challenges-catalog
  pattern; a checker that never says no is not a checker).

---

## 3. K3 — Proof-carrying obligations

### 3.1 The argument (why this design, stated against Bend 2's published shape)

Bend 2's public position: `LAWS.bend` is "AGENTS.md backed by proof," the AI writes `PROOF.bend`, the type
checker is "a proof checker, as in Lean and Rocq" but takes under a second, and NeoGen synthesizes —
"if it fails, an LLM is called," under the discipline of formal correctness. Three structural weaknesses:

1. **Laws are hand-authored.** Bend 2 itself documents that it cannot prevent errors in the
   specifications — the laws are only as good as their author. Koru's obligations are grammar-derived:
   mint/move/discharge edges follow from the invocation shape. There is no law-authoring step to get wrong.
2. **Proofs enter via LLM drafting.** At scale, LLM-drafted proofs are exactly the practice that produces
   plausible-but-wrong derivations; the design's integrity then rests entirely on the checker — which is
   proprietary, fast-by-claim code on an immature substrate (HVM2's own paper concedes the compiler is
   "extremely immature"; Bend 1 programs do not even carry over).
3. **Nothing in the chain carries a machine-checked soundness theorem.** Speed of checking is claimed, not
   proven; correctness of the checker is trust in a company, not a kernel.

Koru's design closes all three: **grammar-derived obligations** (no spec authoring), **algorithmic witness
synthesis** (no LLM in the trust chain — and none needed, because the fragment is decidable), and a
**checker whose soundness is a Lean theorem**. The checker is not fast because it is clever; it is fast
because the obligation calculus is a tiny decidable fragment, and it is trustworthy because its soundness
is machine-checked — the same reason CompCert's validators are trustworthy.

### 3.2 Non-negotiables (the N-list)

- **N1 — Solver ≠ checker.** koruc's obligation solver is untrusted, however good it is. A discharge is
  accepted only on the checker's verdict. Solver/checker disagreement → refusal naming both.
- **N2 — The checker is small, stable, machine-trusted.** The obligation calculus is formalized in Lean;
  soundness theorem: a checked witness implies runtime obligation safety (no leak, no double-discharge, no
  use-after-discharge) under the small-step semantics of flows. The in-tree Zig checker is cross-checked
  batched against the Lean checker (lean_eval pattern: one `#eval` per batch; missing Lean oracle = FAIL).
- **N3 — Witnesses are data.** Synthesized at comptime, attached to the flow record like the existing
  FLOW/PROC/BRANCH source markers; never hand-authored; removing them is a refusal (load-bearing like
  sha256 digests in golden fixtures).
- **N4 — Forged-witness gates are standing.** Known-bad witnesses must be rejected. A checker that
  accepts a forged witness is a red battery, not a caveat.
- **N5 — No LLM in the trust chain.** LLMs may draft Lean lemmas about the checker; the Lean kernel decides
  and nothing else does. Synthesis is algorithmic: grammar-bounded accessor sets make mint/move/discharge
  edges finite and statically enumerable. Where synthesis fails (recursion-depth walls — the
  liveness-interval ruling), refusal is the honest output, consistent with existing koru rulings.

### 3.3 Shape questions for Lars (the S-list)

- **S1** witness surface: header annotation vs. sidecar vs. debug-build-only artifact.
- **S2** whether refusals render the failed witness (debuggability).
- **S3** checker placement: in-tree Zig checker + external Lean oracle (the fasmg pattern), and/or also
  exposed as a comptime tor so the stdlib self-checks.
- **S4** KORU code vocabulary for witness mismatches.
- **S5** first-calculus fragment: which obligation kinds (proposal: the one-label-one-disposer kinds —
  `allocated!`, taken-row custody, held handles — 690_007/690_015 territory).

### 3.4 Estimator

Why smaller than CompCert: the memory-model and aliasing chapters have no spelling in koru; the simulation
invariant is a cell-valuation map plus binding environment, local per branch. First fragment: one obligation
kind, the take/consume-or-give-back cell flow, one Lean file, one gate. The xdu-style equivalence cell from
K1 is the executable shadow of the eventual simulation lemma.

---

## 4. K4 — Attested CI (zk receipts)

- **Battery-in-guest:** RISC-V guest (koruc cross-builds; ccomp's RISC-V port; fixtures + sha256 manifest).
- **Receipt pins:** git tree hash, koruc binary digest, ccomp digest, fixture manifest, gate list and
  outcomes. Verifying the receipt ⇒ "the battery ran honestly on these artifacts and passed."
- **Tiering (declared schedule regimes, not moods):** fast tier native per commit; zk tier on releases and
  at a declared interval.
- **New certificate tier:** `attested` between `witness` and `proof` (echoes the agents-store certificate
  table; a receipt is a process certificate, priced accordingly).
- **Honesty clause:** receipts attest process, not semantics. The pyramid stands.

---

## 5. Sequencing

- **K1** starts now on `ccomp`.
- **K3's long pole is the Lean calculus** — it starts immediately, in parallel, and gates nothing until its
  first fragment lands.
- **K2** is opportunistic once K1's emitter stabilizes.
- **K4** after K1 (needs a stable battery); rides the agents-store certificate regime where convenient.

**Foot-down summary for the Lars conversation:** N1–N5. Everything else is shape.

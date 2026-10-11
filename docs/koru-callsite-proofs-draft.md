# Call-site proofs — co-design draft

Status: **DRAFT for co-design with Lars.** Nothing here is implemented or
proposed as decided — every surface choice below is a question. Measured
against `fdebdf7cf` on `ccomp`.

Pins against `docs/koru-verification-path.md` N1–N5 (§3.2), S-list (§3.3),
and the resolved checker placement (§3.5).

## 1. Purpose, in one paragraph

Obligations already exist: grammar-derived mint/move/discharge
requirements the compiler tracks today (`?!` decls, `<state>` phantoms,
the auto-discharge family). The missing half is the *artifact*: a
synthesized witness, attached to the flow record at the call site, that
the trusted `witness-check` pass can rule on — "call-site proofs," where
the proof object is data (N3), produced by an algorithmic solver (N5),
and the checker's verdict is the only thing that counts (N1).

## 2. The three surfaces the AST already offers

All three exist today; none needs new grammar.

| | surface | substrate | hand-authorable? |
|---|---|---|---|
| **A** | `[proof(...)]` annotation | `annotations: []const []const u8` on EventDecl/ProcDecl/NamedBranch/Flow — opaque strings, `parseCall` splits `name(args)`; `~[a|b]` vertical blocks attach forward | **yes** |
| **B** | `proof(...) { opaque }` invocation | Lars's suggested spelling — namespaced invocation with opaque block; `print.blk {}` is the in-corpus instance, `ProcDecl.body: Source` is the typed-opaque substrate | **yes** |
| **C** | `.marks` | compiler-internal channel — "pass-produced only, never parsed from surface syntax" (`ast.zig:1620`); live precedent: `auto_discharge_inserter` already stamps `@scope` (`:1035`), `@auto-exit-disposal` (`:365`), `@pass_ran("transform")` on `inv.marks` | **no — unspellable** |

## 3. The core distinction: claim vs artifact

A and B are *surface syntax* — anything the user can write can be forged,
so a proof entered that way is a **claim** the checker re-verifies, not
an artifact it trusts. That is legal under N3 only in the weak reading
("hand-authored is allowed but never trusted") — in which case the
witness contributes nothing over the bare obligation, and the checker
does all the work anyway.

C is the only surface where N3's "never hand-authored" is **enforced by
grammar** rather than policy: a `.marks` witness cannot be spelled in a
`.k`/`.kz` file at all. Forging requires compiler-internal access — which
is precisely the test harness N4's forged-witness gate wants anyway.

And C is not speculative: the pass that *becomes* `obligation-synthesis`
(today's `auto_discharge_inserter`) already writes marks on the flow
record. The channel the doc calls "like FLOW/PROC/BRANCH markers" is the
same mechanism, in production, on the same pass.

## 4. Recommended skeleton (Lars decides every surface)

- **Synthesis → C.** `obligation-synthesis` stamps witness edges
  (mint/move/discharge — the grammar-bounded, finite-enumerable set N5
  assumes) onto flow records via `.marks`. Never parsed from source →
  unauthorable by construction.
- **Rendering → B-shaped, read-only.** For S2 (does a refusal render the
  failed witness?), `proof(...) { ... }` is a good *debug* surface — a
  readable rendering the checker emits on refusal, and possibly a
  `--show-witness` dump — explicitly not a spelling the parser accepts.
- **A stays spare.** If a user-visible "this call site is proved"
  annotation is ever wanted (documentation, assertion, opt-out marker),
  `[proof(...)]` is free — but it must be treated as a *claim the checker
  verifies*, never as the artifact.

Net: the first calculus fragment needs **no new surface syntax**. Lars's
co-design condition is satisfied — nothing here adds spellings; the only
questions are which existing channel carries the data and how failures
render.

## 5. Pipeline placement (S3, already resolved §3.5)

```
elaborate |> analysis |> obligation-synthesis |> witness-check |> optimizer |> emission
```

- `obligation-synthesis` — untrusted solver (today's auto-discharge
  family): mints witnesses, may rewrite, owns no verdicts.
- `witness-check` — trusted verdict pass: `Program + Witnesses →
  Program + verdicts | refusals`; never rewrites; idempotent.

Lean's two roles per §3.5: the calculus + soundness theorem (Role A),
and the batched conformance oracle the Zig checker is cross-checked
against (Role B). Lean 4.31.0 is already pinned in `tools/tools.json`.

## 6. Open questions — the consolidated list

Tagged by who can close them. **[Lars]** = language/spelling/semantics
ruling. **[survey]** = mechanical, the agent can measure the corpus and
bring data. **[either]** = design discussion.

### Witness surface (new, from this draft)

- **W1 [Lars]** — does the witness ride `.marks` (unauthorable, my
  recommendation) or a surface spelling? If surface: claim semantics —
  the checker re-verifies it like an obligation, and "hand-authored
  witness" becomes a forge-attempt class for the N4 battery.
- **W2 [Lars]** — S2: does a witness-check refusal render the failed
  witness, and how — stderr diagnostic, a `proof(...) { }` rendered
  block, a sidecar artifact, or a `--show-witness` flag?
- **W3 [Lars]** — S4: KORU code vocabulary for witness failures. One
  code family for all of {missing, malformed, forged, stale,
  solver/checker disagreement}? Numbering is Lars's — check
  `scripts/registry_reserved.txt` for the free range.
- **W4 [Lars]** — S5: confirm the first fragment is the
  one-label-one-disposer kinds (`allocated!`, taken-row custody, held
  handles — 690_007/690_015 territory) or another seed.
- **W5 [survey]** — which obligation *kinds* the corpus exercises today
  (`?!` decls, `<state>` phantoms, `claim`s, `store` slots…) and how
  often each — input to W4, I can enumerate.
- **W6 [either]** — witness data shape: presumably the ordered edge
  list (mint/move/discharge) + the obligation ids they satisfy. Concrete
  encoding is implementation work once W1 lands.
- **W7 [Lars]** — the pass split is mechanical *except* verdict
  ownership: today `phantom_semantic_checker` issues verdicts (KORU030
  ruling) and `auto_discharge_inserter` rewrites. Does `witness-check`
  absorb the verdict role, or wrap the existing checker as an adapter?

### C-lane (from `docs/koru-c-lane-test-plan.md`, still open)

- **C1 [Lars]** — `!`-arm scope: does refusal row 2 cover *all* `!`
  arms — including `for ! each` / `capture ! as`, which would exclude
  every counted loop and the doc's own G-CC-1 sieve class — or only
  resumable producer/consumer pairs? The lowering row "continuation arm
  → caller-side switch" implies some arm shapes lower; which?
- **C2 [Lars]** — refusal ordering when a program co-presents several
  out-of-scope constructs: first-seen, canonical precedence, or a
  refusal that names every axis? (All three refusal cells are
  deliberately co-present.)
- **C3 [Lars]** — the missing-variant axis: a zig-only proc on
  `--lang=c` — is that refusal row 1's "host lines", a `NoCProcBody`
  diagnostic, or its own row? It's the axis most programs will hit
  first (every `std/io` call until `|c` impls exist).
- **C4 [Lars]** — row-4 exemplar: no corpus test spells a
  comptime/transform tor *leaking* a runtime effect; `400_211` is
  reserved for whatever that spelling turns out to be.
- **C5 [Lars]** — `.kc` facet semantics: `file_types.zig` maps
  `.kc`→`"c"` but no `|c` proc or `.kc` file exists in the tree — is a
  `.kc` facet "C host lines + `|c` procs", or something narrower?
- **C6 [survey]** — I can produce the co-presence matrix (which
  construct families co-occur with which refusal rows across the corpus)
  before C2 is decided, so the ruling sees the real collision rate.

---

## verify-path session (2026-10-11) — surveys + recommendations

Measured at `ce877ccd3` (branch `verify-path`, cut from ccomp tip).
Survey items filled with corpus numbers; the [Lars] items carry
**recommendations, not rulings** — Lars decides each.

### W5 — obligation-kind census (resolved, measured)

Counted over `tests/regression/**/input.*` (2309 test dirs):

| kind | spelling | count | notes |
|---|---|---|---|
| cleanup phantoms | `*T<state!>` | **561 occurrences, 59 distinct labels, 263 files** | dominant kind; top labels `owned!` 149, `open!` 46, `active!` 42, `opened!` 39, `live!` 31 |
| borrows | `*T<state>` (no `!`) | 594 occurrences | read borrows — no discharge obligation |
| store custody | `std/store:take|insert|discharge` | 261 files | take = mint, insert/discharge = settle; `! discharge` arms in 18 files |
| panic branches | `\| ?!name T` | 88 occurrences | let-it-crash family (830_*); an obligation to *handle or declare*, not to discharge a resource |
| effect `!` arms | `! arm |> ...` | ~1547 arms, 636 files | resumable continuations — different grammar than phantoms, C1 territory |
| claims | `x = mod:tor(args) ! ...` | present (400_207 pins the shape) | impl-override binding head — cross-module custody claims |

W4 consequence: the corpus's center of gravity is exactly the proposed
seed — one-label-one-disposer kinds (`allocated!`/`owned!`-family +
store take/insert). A first fragment covering `<state!>` phantoms +
store custody covers the corpus's majority case.

### Recommended rulings (Lars decides each)

- **W1 — `.marks`.** Verified `src/ast.zig:1619` — "pass-produced only,
  never parsed from surface syntax" on Invocation/Flow/binding marks,
  and `auto_discharge_inserter` already stamps them in production. It is
  the only channel where N3's "never hand-authored" is enforced by
  grammar. Recommendation stands: `.marks`.
- **W2 — stderr diagnostic + `--show-witness`.** The refusal names the
  obligation id and the failed edge, KORU030-style; the flag dumps the
  edge list. `proof(){}` may exist as a *rendered* debug form — the
  parser must never accept it as input.
- **W3 — one code, message names the fault.** KORU160–178 convention:
  one code per class, the message carries {missing, malformed, forged,
  stale, disagreement}. Reserve a single witness-refusal code rather
  than five.
- **W4 — yes, one-label-one-disposer.** Census above: `<state!>` +
  store custody is the corpus's center of mass.
- **W6 — ordered edge list + obligation ids.** Concretely: each mark
  carries `op(mint|move|discharge), obligation_id, site`; the solver's
  claim is "this list covers the obligation set." Encoding detail is
  implementation work after W1; `marks` being `[]const []const u8`
  means either a serialized form inside the string or marks growing a
  typed payload — cheap either way, name it when W1 lands.
- **W7 — absorb, don't wrap.** `phantom_semantic_checker` becomes the
  obligation-set *producer* (untrusted enumeration is fine — it is data
  the verifier checks completeness against); `witness-check` owns the
  verdict via edge replay. Keeping two verdict-issuers means every
  solver/checker disagreement is a refusal naming both — which under N1
  is the cross-check working, not a bug.

### One clarification worth making explicit

`std/witness` as a *user-authored surface* would be the anti-goal —
W1's forge-attempt class by construction. The name is only defensible
as the **checker service** (the §3.5 "stdlib self-check" idea:
`witness-check` exposed as a callable comptime tor so library code
gates its own discharge sites — the Open Verifier shape). Witnesses
themselves are compiler-produced receipts; the analogy to
`std/invariants` fails on every axis: invariants are user-authored
claims nobody enforces, witnesses are machine-generated evidence a
machine verifies.

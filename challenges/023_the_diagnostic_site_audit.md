---
challenge: diagnostic-site-audit
kind: frame
status: standing
yields: verified diagnostic-site defects in one audited emission family, each pinned by a test or a fix — and a ledger row for every site read, clean ones included
family: toolchain
created: 2026-09-12
---

*Walker context — the recurrence that earned this frame. On 2026-09-12 Lars used
the toolchain as a human for under forty minutes and hit cracks in the first
two. One `frames(win: w, count: 30)` call, three errors, four defects:*

```
- kind-blind: a missing `!` arm was told "no continuation found" — the
  remedy it spells is `|`, which walks the user into KORU025 kind-mismatch
- where: all three errors pointed at the [with] flow head, line 4 — the
  offending call is line 7; the caret names an ancestor, not the fault
- arity: one fault, three reports — an aggregate "branches are not handled"
  plus the two per-branch errors it subsumes
- never-false: the same aggregate fired when every declared branch was
  optional — an error with no fault behind it
```

*The pilot that followed read ~110 `addError*` emission sites in
`shape_checker.zig` + `flow_checker.zig` against five questions and produced
**5 location fixes, 1 wording-drift finding, and 1 latent false-positive
killed** — in a single pass, over two files, in one session.*

***The suite carries ~200 diagnostic emission sites and they are read only when
a user trips on one.*** *The board mines what is red. `018` mines the green from
the user's side — compile a program, report what was odd. `021` mines the green
from the machine's side — read what the compiler ships. **This frame reads the
machinery itself:** the call sites that produce every diagnostic, audited
against a fixed lens. The user finds quirks one at a time; the emission-site
audit finds the *class* the quirk belongs to — today each quirk traced to a
site-level pattern (inherited location, kind-blind vocabulary, aggregate
double-report), not a one-off bug.*

---

## The brief (sealed — you are the contestant)

**Pick an emission family and read every diagnostic site in it, against the
lens.** Not behavior — that is `018`'s faucet. The *sites*: each `addError`,
`addErrorAtLocation`, `reporter.addError*` call in the files you take. Enumerate
them first; an audit that samples is a stroll.

An emission family is a shardable slice: one checker's diagnostics
(`shape_checker.zig`'s remaining sites), one organ (`parser.zig` parse errors,
`auto_discharge_inserter.zig` obligation errors), one code (`every KORU030
site`), or one surface (CLI messages, crash reports). Declare the family's
boundaries before you start and count its sites — the ledger needs a denominator.

For each site, answer **the five questions**:

1. **where** — does the caret land on the thing the user must change, or on an
   ancestor? The fault has an owner; the location must name it. `cont.location`
   and `proc.location` exist — sites that pass the flow head instead are the
   day's most common defect.
2. **what kind** — does the message use the declaration's kind vocabulary? An
   effect `!` is not a terminal `|`; the missing object is a *handler*. A
   message that names the wrong kind teaches the wrong remedy.
3. **arity** — does one fault produce one diagnostic? Aggregates that re-report
   what specific errors already say are double reports; errors that fire in
   packs where one carries the fault are noise.
4. **remedy** — does the message teach the spelling or action required? "no
   continuation found" does not tell a user to write `! frame f |>`.
5. **never-false** — can the diagnostic fire when nothing is wrong? Read the
   guard. All-optional branch sets, empty continuations, wildcard decls —
   the false positive lives where the check forgets a carve-out.

Return **a ledger, not a highlight reel**: every site in the family, marked
defect / clean / drift / needs-ruling. Clean rows count — "audited, no finding"
is a result the next replay builds on.

## The finding class this frame wants

Rank by this ladder:

1. **Never-false positives.** An error that fires with no fault behind it —
   the worst diagnostic is the one that cries wolf on a correct program.
2. **Carets on ancestors.** The error names line N but the fix belongs at
   line N+k; the user edits the wrong place and learns the wrong lesson.
3. **Kind-blind remedies.** The message spells a fix the kind system will
   refuse — effect told as continuation, terminal told as handler.
4. **Duplicate and aggregate reports.** One fault, N errors; or an aggregate
   beside the specific errors that subsume it.
5. **Wording drift across passes.** The same rule with two sentences —
   shape says one thing, flow another. The diagnostic registry has one
   meaning; two wordings is a second wall waiting to drift.
6. **Remedies that don't teach.** The message names the fault but not the
   spelling — where a hint or a `for example` line would.

## Ground yourself FIRST

**Read the site before judging the message.** The location passed, the guard
conditions, the fallback — the defect is in the plumbing, not the prose.
`location` inherited from a caller three frames up is the day's signature.

**Reproduce before you claim.** A defect you did not trigger is narration —
write the smallest `.kz` that fires it, read the caret, then call it a finding.
`unmeasured` is not a finding.

**The arm owns the error.** When the diagnostic is about a specific
continuation, proc, or arm, its `location` field is the honest caret —
`cont.location`, falling back to the call site only when `line == 0`. This
is the established convention in the same files; sites that ignore it are
the defect.

**A finding is the pin, not the observation.** For every confirmed defect the
deliverable is the fix + the regression test that would have caught it, or a
recorded reason it can't be pinned. And an honest answer to *why the board
did not* — name the category of blindness.

## ⚖️ Make a qualified guess, never a verdict

Same stance as `018` and `021`. Two readings, and they are not yours to choose
between:

- **(A) the site is wrong** — a real defect in location, kind, arity, or
  remedy.
- **(B) it is deliberate** — a broad location is the only honest one (the
  fault genuinely has no narrower owner), the aggregate is the user's first
  summary, the wording is pinned by an intentional contract.

Write **both**, then lean with confidence: `grounded` (you cite the site, a
repro, a pin) is the only level where a hard lean is allowed; `inferred` is
reasoning without a citation; `unsettled` is a frontier — often "the message
is right but which location is honest needs a ruling" (today's column-0 and
per-link chain locations are exactly this: they need parser provenance, which
is a design call, not a fix).

⛔ **Do not flatten diagnostics to silence the audit.** If a broad location is
honest (the fault owns the whole flow), say so — do not move carets to look
busy. A `cont.location` slapped on a flow-level verdict is its own defect.

## Known territory, already claimed — do not re-mine

- `shape_checker.zig` + `flow_checker.zig` branch-coverage sites: audited
  2026-09-12, fixed in `fa026be34`. KORU021/028/030/101 arm-level locations,
  KORU022 kind-aware wording, KORU040/arm-fire step locations, when-clause
  location threading, aggregate dedup. Read the commit, not the old state.
- Obligation/phantom diagnostics in `phantom_semantic_checker.zig` +
  obligation/auto-discharge diagnostics in `auto_discharge_inserter.zig`:
  audited 2026-09-12, ledger below. Arm-owns-the-error threading landed
  (`cont.location` with line-0 fallback through `validateContinuation`,
  `validateContinuationAsVoidChain`, `validateNamedBranchRecursive`,
  `checkContinuation`, `checkForeachBranchContinuation`,
  `insertDisposals`, `insertDisposalsInForeach`, `creditConsumingArgs*`),
  decl-coordinate translation at KORU033/040/083, `_auto_N` display fix,
  dup-proto prose lines via `userLineIn`. Pins: 330_127–330_132.
- Per-link chain locations: traced to `stitchPipeChainLines` flattening —
  every `|>` link inherits one `chain_location`. Needs parser provenance
  (a design call on `parser.zig`), not another audit.
- **Two coordinate systems, one trap.** AST-decl locations
  (`getUserDeclStartLocation` — EventDecl et al.) are stored in USER
  coordinates because `--ast-json` consumers read them raw (210_164 pins
  this). `addError*` stores PARSER coordinates and `classifyLine`
  subtracts the injected prelude at render. Any site that hands a decl
  location to `addError*` double-subtracts — caret lands one line early,
  `:0` for a line-1 decl. Sites in future families: check which
  coordinate the location field is stored in before trusting it.
  Prose-embedded line numbers must go through `userLine`/`userLineIn`.
- KORU050/021 two-wordings drift: logged, wants a shared `errors.zig`
  helper or a ruling.

## What "done" looks like

- The family declared, its sites enumerated and counted.
- A ledger: every site → defect / clean / drift / needs-ruling, with the
  five questions answered for the defects.
- For each defect: the repro, the fix or the ruling request, the pin, and
  the category of blindness.
- The ledger appended to this file's history (or the catalog), so the next
  replay knows the audited frontier — a family fully read is exhausted
  until the code moves.

## Failure modes

- **Sampling instead of enumerating.** "I looked at some sites" is not an
  audit. Count the family first.
- **Judging messages without reading guards.** The never-false check lives
  in the condition, not the string.
- **Reporting without reproducing.** A site that *looks* wrong but you
  never fired is a guess, not a finding.
- **Moving every caret narrower.** Some faults honestly own the whole
  flow — over-precise carets are a defect class too.
- **Re-mining audited ground.** Read the claimed-territory list; spend the
  replay on unclaimed families.
- **Calling drift a defect without checking which side is canonical.** Two
  wordings means one is right; find the pin before filing.

---

## Ledger — 2026-09-12 — obligation/phantom family (worktree `diag-023-oblig`, base `216ae42e9`)

**Family boundaries.** Every `self.reporter.addError*` emission call in
`src/phantom_semantic_checker.zig` (obligation tracking, phantom-state
argument validation, polarity, stale-read, scope/conservation walls) and
`src/auto_discharge_inserter.zig` (auto-discharge candidate selection,
scope-exit walls, outer-scope discharge, call-site arity, `[!]`-default
shape, strict panic-branch). Non-emitting calls (`hasErrors`,
`printErrors`) excluded. **Denominator: 47 sites — 27 checker + 20
inserter.**

### Defects found — all `grounded` (site + live repro + pin)

**D1 — Decl-coordinate double-subtract (the family's worst defect class,
ladder rung 2: caret on the wrong line entirely).**
`parser.getUserDeclStartLocation` stores `EventDecl.location` in *user*
coordinates (deliberate: `--ast-json` reads stored locations raw, pinned by
210_164), but `addError*` treats stored lines as *parser* coordinates and
`classifyLine` subtracts the injected prelude line at render — so every site
that hands a decl location to `addError*` renders one line early: onto the
blank line above `~tor`, or `:0` when the decl sits on line 1.

- Sites: checker 754/767 (KORU033 issue/consume polarity), 779/801 (KORU040
  unknown phantom module, concrete + union-member arms); inserter 3288→3297
  (KORU083 `[!]` on non-void tor). All five reachable through
  `validatePhantom`'s six `event_decl.location` callers.
- Repro: `~tor mk { bad: *Handle<owned!> }` on line 4 → caret `:3:0` on a
  blank line; on line 1 → `:0:0`. After fix: the `~tor` line.
- Fix: translate user→parser coords at the diagnostic site
  (`line + injection_line_count`, same-file guarded) — inside
  `validatePhantom` once for all four checker sites; inline at KORU083.
- Pins: `330_130_polarity_diagnostic_names_the_tor_decl` (KORU033),
  `330_132_default_discharge_annotation_names_the_tor_decl` (KORU083).
- Board blindness: **location-blind pins.** Existing EXPECTs assert message
  text only (`CONTAINS`); no `ERROR_AT` existed anywhere in the obligation
  clusters, so a caret on a blank line stayed invisible. Also a
  **coordinate-scheme trap**: two line-number spaces coexist in the AST and
  only render-time translation separates them — nothing type-level marks
  which space a `SourceLocation` is in.

**D2 — Inherited flow-head location through the whole continuation walk
(ladder rung 2).** `validateContinuation` threaded the caller's `location`
(flow head) into every nested call, so every continuation-specific
diagnostic — unknown branch, arg mismatch, use-after-discharge, stale read,
missing tracked binding, hard-terminal leak, label-jump conservation —
pointed at the flow head regardless of which arm owned the fault.

- Sites: checker 1895/1911 (`reportLeaksAtHardTerminal`), 2234, 2695/2713,
  2918 (`validateContinuationAsVoidChain`), 3038 (label jump), 3300/3313,
  3365/3409 (`reportStaleReads`), 3484–3849 (ten `validateArgument` sites)
  — all consumed a `location` param that was always `flow.location` at root
  and never re-derived per arm, despite `ast.Continuation.location` existing.
- Repro: `| good g |> peek(h: g)` arm leaking `<owned!>` on line 37 → caret
  `:36:0` on the flow head; `use-file` after `close` → UaD at flow head.
  After fix: the arm's own line.
- Fix: `const location = if (cont.location.line != 0) cont.location else
  caller_location` in `validateContinuation`,
  `validateContinuationAsVoidChain`, per-cont in
  `validateNamedBranchRecursive`, and `nested.location` for the nested-arm
  fallback loop — one-line derivation per frame, convention copied from
  `fa026be34`.
- Pin: `330_127_arm_owns_obligation_leak` (checker hard-terminal leak at the
  arm; `--auto-discharge=disable` so the wall, not the inserter, is under
  test — same staging as 330_122).
- Board blindness: same location-blind-pin category; the arm convention was
  established for shape/flow checkers but nobody re-checked whether the
  obligation checker had adopted it — **adoption-gap blindness**: a fix
  landed in one family and its twin file was assumed fine.

**D3 — Label jump names compiler-minted `_auto_N` (ladder rung 3-adjacent:
the message names an object the user never wrote).**
`| again _ |> @loop()` discards the payload; the inserter renames `_` to
`_auto_0`, and the KORU030 conservation diagnostic printed that synthetic
name — unactionable and unreadable. Also inherited the D2 location defect
(caret on a blank line past the jump).
- Site: checker 3038 (was 3002 pre-fix).
- Repro: `330_075`'s own input — caret `:31:0` on a blank line, message
  named `_auto_0`. After fix: `:36:4` on `| again _ |> @loop()`, naming
  `input:*Handle` (the binding's declared base type — the same display rule
  `reportLeaksAtHardTerminal` already applies to `_auto_N` and `s.field`
  paths).
- Fix: site replicates the established display-name rules (dot-suffix strip,
  `_auto_` → `base_type`).
- Pin: `330_128_label_jump_names_arm_and_source_binding` — `ERROR_AT` +
  `NOT_CONTAINS _auto_`.
- Board blindness: **text-pin blindness** — `330_075`'s EXPECT asserted
  `CONTAINS "drops cleanup obligation"` only; both the blank-line caret and
  the synthetic name were invisible to it.

**D4 — Inserter obligation diagnostics at `flow.location` (ladder rung 2).**
Every inserter wall that names a continuation-owned fault reported at the
flow head:

- `insertDisposals`/`insertDisposalsInForeach` (3188/3202/3218, 2923/2931/2947):
  "not discharged / Call one of / multiple discharge options" — the leaking
  continuation's exit owns it → `cont.location`.
- `creditConsumingArgsForDecl` (3092 KORU032 outer-scope discharge; 3114
  field-path double-discharge): the invocation's arg owns it → threaded
  `site_location` through `checkInvocationSatisfiesObligations`/
  `creditConsumingArgs` from the enclosing `cont`.
- Scope-exit walls (1722/1730/1748 on `cont`; 2566/2574/2590 on a
  `NamedBranch`): `NamedBranch` carries no location — nearest honest caret
  is `branch.body[0].location` (the `! each` arm's first line).
- Repros: `repro_scope.k` KORU032 `3:0`→`7:4` (the `! each` arm);
  `repro_scope_amb.k` ambiguity `3:0`→arm line.
- Pins: `330_129_scope_discharge_names_the_arm` (KORU032),
  `330_131_scope_exit_ambiguity_names_the_arm` (multiple-options at
  scope exit).
- Board blindness: adoption-gap + location-blind pins, as D2.

**D5 — Duplicate-identity prose line numbers in parser coordinates
(ladder rung 5, wording drift inside one message).** The caret at
`site.location` was correct, but the prose embedded `site.location.line` /
`prior_loc.line` raw — the "declaration at file:N" the user read was off by
the prelude height (1).
- Sites: checker 251/262 (`registerDeclaredIdentity`, KORU030 dup
  foreign/proto).
- Fix: `userLineIn` on both embedded numbers — exactly what
  `errors.zig:293`'s doc prescribes for prose-named lines.
- Pin coverage: existing 665_003 / 660_029 / 660_031 / 667_002 pins assert
  the prose shape (`CONTAINS collides with the prior registration`) and all
  still pass; a dedicated line-number pin would need a bespoke `~proto`
  collision repro — recorded here as fixed-and-verified-by-neighbor rather
  than separately pinned.
- Board blindness: **prose-blind pins** — expectations match message text
  loosely enough that a wrong embedded line number reads identical.

### Clean sites (verified — deliberate location or correct arm already)

- Inserter 1144 (KORU080 missing required input): already threads
  `cont.location` per-continuation (line ~1097) — the convention existed in
  this file and D4's sites ignored it.
- Inserter 1237 (KORU112 bare module-scope ref): `proc.location` — the proc
  owns the fault.
- Inserter 1905/1913 (flow-level silent-drop audit): `flow.location` is the
  honest caret — the binding is by construction absent from every arm; the
  audit is a property of the whole flow exit.
- Inserter 4914 (KORU022 strict panic branch): `flow.location` — the missing
  handler is absent, nothing narrower to point at.
- Checker 2234 unknown-branch and all `validateArgument`/`reportStaleReads`/
  `validateEventContextPhantom`/`validateSingleInvocation` sites (3313,
  3365, 3409, 3484–3849): were D2-defective by inheritance, now arm-correct;
  wording/kind/remedy already sound (state names, `Call one of:` lists,
  parameter names).

### needs-ruling / unsettled

- **Per-link precision inside a chain.** A UaD on the *second* `|>` link of
  an arm reports at the arm's start (column of `|`), not the offending link
  — e.g. `repro_nested.k` fires at `3:4`. Correct line, wrong column-ish:
  needs per-link provenance from `stitchPipeChainLines` — already claimed
  parser-provenance territory, not re-litigated here.
- **`flow.location` initial binding at checker's 1608/1668**: the flow-head
  invocation's own args are judged at the head line — honest.
- **Aggregate arity**: `reportLeaksAtHardTerminal` can emit one diagnostic
  per leaked binding at one arm (observed: `h0` + `g`, two real faults) —
  that is N faults, N diagnostics, not double-reporting. Clean.

### Verified vs unverified

- `zig build` clean; all five+one pins green through `./run_regression.sh`
  with `KORU_STDLIB` pointed at this worktree (two targeted runs: 33/33 and
  12/12, `Running N tests` matched the request both times). Repro carets
  read from the live `zig-out/bin/koruc` built from this tree.
- Backend builds in this worktree still resolve `src/` through
  `/usr/local/lib/koru` (the main-checkout symlink — known phantom); the
  pinned assertions are all frontend diagnostics emitted by the worktree
  `koruc` snapshot the suite builds (`zig-out-run-*/bin/koruc`), so the
  verdicts stand. No backend-behavior claim is made.

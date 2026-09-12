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
- Per-link chain locations: traced to `stitchPipeChainLines` flattening —
  every `|>` link inherits one `chain_location`. Needs parser provenance
  (a design call on `parser.zig`), not another audit.
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

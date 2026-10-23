# Exclusion ledger — the contract for what is deliberately out of scope

`SKILL.md` carries the why: without a ledger the bar is unreachable, the
plateau is fake, and every round re-derives the same phantom gap. This file is
the **what** — the format, the lifecycle, and the one rule that makes the whole
thing honest: *an exclusion is a judgment, and judgments belong to the walk.*
The proven instance is `~/src/kopium/gauntlet/cordis/LEDGER.md` — nine entries,
all resolved, none ever deleted.

## Where it lives

`gauntlet/<run>/LEDGER.md`, beside `board.jsonl` — in-tree,
version-controlled, one directory per run. The two artifacts are written by
different hands on purpose: **the board is the instrument's file** (facts,
appended, machine-readable) and **the ledger is the walk's file** (judgments,
authored, human-readable). Git is the history; entries update in place and the
diff is the audit trail.

## The entry

One entry per exclusion. The one-line rule from the method: **one exclusion,
one reason** — an entry carrying two reasons is two entries.

```markdown
**`EX-007` — `js-flags` tests: COMPILER_FLAGS the sweep does not model**
- Status: proposed · 2026-10-02 · by: contestant
- Surface: every positive test whose harness needs COMPILER_FLAGS
  (sweep auto-skips them today — 0 measured, silently)
- Reason: instrument-gap — the closer cannot run them, not out of scope
  by any decision
- Settles when: the sweep models flags, or the walk rules them refused
```

- **`Surface`** names the excluded thing *precisely* — test ids, a module, a
  theorem, a count the instrument can recount. "The hard ones" is not a
  surface. The surface must be enumerable, because the board has to subtract
  it from the denominator.
- **`Reason`** carries a class plus the judgment. The common classes:
  **`no-analogue`** (nothing on the target exists to be parity with — a
  Zig-only feature has no JS parity), **`platform`** (an intrinsic the target
  cannot host), **`refused`** (a behavior the reference has and we
  *deliberately* do not want — a decision, not a gap), **`instrument-gap`**
  (the closer cannot measure it — in scope in principle, unreachable in
  fact), **`mis-bared`** (the item measures something other than what the bar
  is about — a harness artifact counted as a parity item). The list is a
  vocabulary, not a wall; a class nobody has needed yet invents itself in the
  entry that needs it.

## The lifecycle — who may move which edge

```
              ┌─→ ratified ──→ discharged (the gap got built; retires with evidence)
proposed ──── ┼─→ rejected  (stays on file — do not re-spend a fleet re-asking)
              └─→ carried   (examined: the gap wasn't there — recorded so it
                            is never re-derived)
```

- **`proposed`** — the *only* state a contestant or instrument may write.
  Anyone may draft; the fleet files here and nowhere else. A proposal carries
  its proposer and date.
- **`ratified`** — moved by the walk. Only ratified entries shrink the board's
  denominator; a proposal sitting in the file does **not** move the score —
  this is the asymmetry that makes proposing safe to delegate. Ratification is
  the gauntlet's one mid-run return to the walk (CONTEXT.md: the ledger is the
  only thing a run hands the walk for a decision), and it happens at declared
  checkpoints or at run end — the loop does not pause for a proposal.
- **`rejected`** — kept. A rejected exclusion is a record that this scope
  question was asked and answered; the next contestant who rediscovers the
  edge finds the answer already written.
- **`carried`** — proposed, examined, and found not to be a gap at all: the
  property already holds, or the surface was misread. Cordis's confluence and
  progress entries were exactly this — recorded as findings, no pin
  manufactured, never to be re-derived by the next round.
- **`discharged`** — a ratified exclusion the run later *closed*: the capacity
  got built and parity now covers it. Retires with evidence — the pin, the
  falsification, the commit — never deleted. Every cordis entry ended here;
  that is the ledger working.

IDs are `EX-NNN`, sequential per run, never reused, never renumbered. An
exclusion is a decision; renumbering is revising history.

## The fraud clause

A contestant's ledger diff may contain **additions to proposed and nothing
else**. A diff that ratifies, discharges, rewrites a surface, or edits a reason
is a self-reporting violation: the walk rejects the diff, not the idea — the
proposal gets re-filed clean and argued on its merits. The check is mechanical
at merge time (`../arbiters/judge.md`): read the ledger diff; if anything moved
that wasn't a new proposal, the contestant exceeded its shell. An unratified
exclusion is conformance fraud with better paperwork — the parity-run form of
editing the test to match the compiler.

## The growth reading

The ledger is the bar's conscience. A run whose ledger grows faster than its
score is discovering that the bar itself was wrong — the fourth exit, and a
finding worth more than the parity (`SKILL.md`). The board computes the ratio
(`scoreboard.md`, *ledger pressure*); the ledger is where it lands.

## Seeding a run — exclusions the instrument already smuggled in

A scope decision embedded in the closer's code is an **unratified exclusion
with a maintainer**. Before the first round, sweep the instruments for
built-in filters and file each as a proposal — the instrument's silence is a
judgment nobody made. For the koru JS-emitter run (measured 2026-10-02), the
embedded filters to surface:

- `COMPILE_TIME` modules in `js-parity-map.mjs` — metacircular pipeline
  surface a user program never reaches; excluded by the map before counting.
- `MUST_ERROR` / negative tests — outside the sweep's "positive MUST_RUN"
  candidate pool. Refusal parity is a separate claim from behavior parity;
  say so explicitly rather than inheriting it.
- `LANGUAGES`-marked tests — the opt-in measured set; the sweep treats the
  unmarked complement as the canary. Which population the bar covers is a
  walk decision.
- `js-flags` skips — tests needing `COMPILER_FLAGS` are auto-skipped by the
  sweep: zero measured, silently out. `instrument-gap` until ruled otherwise.
- `blocked-on-test-host` (181 tests) — host fixtures unported. In scope in
  principle; whether "blocked" means "excluded this run" is a ledger line.

Each lands as `proposed` with the instrument location cited as its surface —
and the walk ratifies the set before the fleet spends a round on a test that
was never in the bar.

# Scoreboard — the contract for the board a gauntlet runs on

`SKILL.md` carries the why: an autonomous loop is *watched*, not asked, and the
board is what permission would have bought, cheaper. This file is the **what** —
the format every gauntlet board keeps, the fields every round emits, and the
readings a glance is allowed to draw. The proven instance is the cordis run
(`~/src/kopium/gauntlet/cordis/` — the README's rung table, `FIRST_PULL.md`,
`RUN_01_VERDICT.md`); the first run written *against* this contract is koru's
JS-emitter parity.

## Where it lives

One directory per run: `gauntlet/<run>/` in the repo under test — in-tree,
version-controlled, committed as it grows. The board is two files, and the
distinction between them *is* the contract:

- **`board.jsonl`** — the truth. Append-only, one JSON object per round, written
  by the runner after the closer renders. Rows are never edited, reordered, or
  deleted; a corrected measurement is a new row, never a rewrite.
- **`BOARD.md`** — the glance. Regenerated from `board.jsonl` alone after every
  append, so the human can read progress mid-run without stopping the loop.
  Disposable by construction: if deleting it and re-rendering loses
  information, the truth was living in the render and the contract was already
  broken.

## The round record

One line per round. These fields are required; a row missing any of them is not
a measurement, it is a story about one.

```json
{"round": 7, "at": "2026-10-02T14:31:07Z", "tree": "abc1234de", "dirty": false,
 "bar": 1.0, "score": 0.417, "delta": 0.003,
 "scope": {"in": 1306, "ratified": 12, "proposed": 3},
 "moved": ["440_010: js-compile→js-pass", "EX-014 proposed"],
 "closer": {"id": "js-sweep", "cantTell": 0.003},
 "budget": {"unit": "rounds", "declared": 40, "spent": 7}}
```

- **`round`** — integer, strictly increasing. Monotonicity is the audit: a gap
  in the sequence is a round that ran unrecorded, which is to say it did not
  happen.
- **`at`**, **`tree`**, **`dirty`** — provenance. When, against which commit,
  whether the tree carried uncommitted edits. A score with no tree is a number
  about nothing.
- **`bar`** — the target, *restated every round*. Bars get re-set mid-run; a
  re-set bar is legitimate only if it is visible, so the row carries the bar it
  was measured against rather than inheriting one by silence. A changed `bar`
  between adjacent rows reads exactly as what it is.
- **`score`** — the current number, in the bar's units. This is the figure the
  exit conditions read.
- **`scope`** — the denominator's composition: `in` is the *live* denominator
  (in-scope minus ratified exclusions — what `score` is measured against),
  `ratified` the count removed, `proposed` the count awaiting the walk. The
  board's mechanical link to `ledger.md`: only `ratified` shrinks `in`, and a
  proposal never helps the score.
- **`delta`** — `score` minus the previous row's `score`. Redundant with the
  history and carried anyway: the glance reads deltas, not diffs of diffs.
- **`moved`** — itemized state changes this round: which items flipped, which
  ledger entries appeared. An empty list is a valid and loud row — it is what a
  plateau round looks like up close. Facts, not prose; the narrative lives in
  the run's verdict file.
- **`closer`** — which instrument rendered the verdict (`id`), plus
  **`cantTell`**: its self-reported unresolved / unclassified / can't-tell
  fraction *for this round*. The calibration pull does not end at the first
  pull — the honesty figure rides every row, so a closer that regresses
  mid-run (a parser drift, a new call shape it cannot resolve) shows up as a
  rising `cantTell`, not as silently moving numbers.
- **`budget`** — the declared ceiling and the burn. A gauntlet without a
  declared budget is unbounded, not autonomous; the row carries `declared` so
  the constraint is provenance too.

## The honesty contract — same as the hub's

**Computed only.** Only the runner appends. A hand-patched row is not a
contribution, it is a corrupted instrument steering an unsupervised fleet —
the exact fraud the board exists to make impossible. If the number is wrong,
the instrument is wrong, and the fix is upstream (tenet 8), in the closer or
the runner, never in the file.

**Provenance visible.** `tree` + `closer.id` on every row; the rendered board
repeats both in its header.

**Freshness visible.** `BOARD.md` renders the age of the last row. A stale
board says it is stale rather than passing for current.

**Self-certifying.** The render checks `closer.cantTell` against the run's
declared trust threshold (set at calibration) and marks the board **DO NOT
TRUST** when it crosses — the same refusal the parity map prints, kept alive
on every round instead of once at the door.

## What a reader may conclude — the derived readings

The board makes four things *computable*, and computing them is the renderer's
job, never a reader's judgment:

- **The gap**: `bar − score`, current and trended.
- **Plateau**: no positive `delta` across the declared window. The window is a
  run parameter — declared with the budget before the first spawn, carried in
  the run's README — so "stopped moving" has a number and plateau is read, not
  felt. (Computable from round two onward; the calibration pull is round zero.)
- **Ledger pressure**: growth of `scope.ratified + scope.proposed` against
  growth of `score`. The fourth exit condition — *the ledger grew faster than
  the score* — is this ratio crossing, rendered where everyone can see it.
- **Exit proximity**: the board states, per row, which of the four exits is
  nearest — bar, plateau, budget, or ledger — so the glance answers "how does
  this end" without a meeting.

What the board is not: a verdict (the run's judgment comes home once, as the
outcome — `../arbiters/contest.md`), a per-round adjudication channel, or a
place for narrative. `moved` is the whole commentary.

## The first row is the calibration pull

`board.jsonl` opens at round 0 — the first pull that measures the closer before
any fleet launches. If `cantTell` is above threshold, the board's first row is
already DO-NOT-TRUST and the run does not fan out; that row is the evidence
that decides whether a run exists at all. A board with no round 0 was built
after the fleet launched, which is the wrong order (`SKILL.md`: build the
board *before* the first round).

**Worked instance.** On the koru JS-emitter run the instruments already exist:
`scripts/js-sweep.py` is the closer (compiles `koruc --lang=js`, runs node,
diffs `expected.txt` — statuses `js-pass`/`js-mismatch`/`js-refused`/…), and
`scripts/js-parity-map.mjs` is the *scope* instrument (which tests are
emitter-testable at all). Two instruments, one board: the closer owns
`score`; the scope map owns `scope.in` and `closer.cantTell`. Measured
2026-10-02 on the live tree: 1306 positive tests in scope, 513 ready —
and the map self-refuses at **27.1% unclassified** (1038 unresolved call
sites, `store:*` and `list:*` dominating). That is a DO-NOT-TRUST round 0:
the gauntlet's first move is a closer fix, not a fleet.

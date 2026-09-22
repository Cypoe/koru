---
type: belief
id: frag-a-watcher-off-the-normal-path-is-not-a-wall
provenance: found while wiring check D into prose-check 2026-07-26 — the watchers sat past the point `--parallel` exits, so the mode the toolchain skill tells you to use had never run them; prose-check's check A had been failing on the event→tor rename for as long as that rename had existed; evolved 2026-09-17 with the sixth rung — the board's brain push had been reporting node's deprecation warning as its failure while the endpoint 500'd on the real payload
ts: 2026-09-17
---

# A guard is only as strong as the path that reaches it (belief)

`run_regression.sh` grew two coherence watchers — diagnostic-code registry drift,
and the no-prose pipeline check — both written as blocking, both commented as
blocking, both appended at the end of the sequential run. Parallel mode returns
several hundred lines earlier. So `--parallel`, which is the invocation the
toolchain skill hands you as *the* way to run the suite, had never executed
either one.

Nothing about this is visible from reading the watchers. They are well written and
they do fire — when reached. The defect is entirely in the topology, and topology
is what nobody re-reads.

## The cost, measured

prose-check's check A compares every generated artifact against its own
regeneration. It had been failing since the `event` → `tor` rename: the by-example
corpus and three generated SKILL.md files still said `~event`. The check designed
to catch exactly that drift had been reporting nothing, because it never ran.

Its check C forbids duplicate `NNN_NNN` test ids. Two sessions independently took
`210_166` the same day. That collision would have been caught at the next full
run — and would not have been, since the next full run was going to be parallel.

## What follows

- **A guard's strength is the probability the normal path reaches it, times its
  logic.** Reviewing only the logic reads the second factor and assumes the first.
- **When a fast path is added beside a slow one, the guards do not come along.**
  The fast path is written by copying the reporting and exit logic, which is
  exactly where end-of-run checks live, and exactly what gets trimmed. Extract to
  a function called from both, so adding a third path has to name it or visibly
  omit it.
- **Prefer the failure that is loud in the common case.** These watchers were
  unreachable in the common case and reachable in the rare one, which is the worst
  arrangement: they cost nothing to keep, produced nothing, and read as coverage.
- **"Blocking" in a comment is a claim about intent, never about reach.** It is
  the same class of thing as a red pin's title — see
  [[frag-a-red-pin-is-unfalsifiable-documentation]] — an assertion no assertion
  checks. The defence is to run the guard and watch it fail on purpose.
- **Reach is necessary and not sufficient: a wall also needs a CONSUMER.** A
  guard that runs, fails, and prints into a log nothing downstream reads is
  back where it started. The question has two halves — does the normal path
  reach it, and does anything act on the answer.

## The same failure one layer in: a guard whose input is not tracked

Check D shipped with its manifest untracked. `tests/regression/.gitignore` is an
allowlist — `*`, then the kept patterns — and the manifest's extension was not on
it, so `git add <path>` printed an advisory hint and exited 0. The commit
succeeded; the lint's only input did not travel with it. For anyone else the check
would have failed with MISSING-MANIFEST, pointing at the manifest rather than at
the ignore rule that ate it.

Same shape as the topology defect: logic sound, reach zero. Reaching now means
being present in the clone, not merely being called. And staging narrowly —
adopted in that session as protection against a concurrent writer in the same
checkout — is what removed the `git add -A` whose diff would have shown the gap.

## The third rung: reached, fired, and published over anyway

Reach was fixed and the belief still had a hole. Check D now runs — and on
2026-08-02 it fired, correctly, on the `sweep`→`query`/`query`→`rule` rename:
a stale row for a transform `koru_std` no longer declares, and no row at all
for the one the rename created. It had been firing since the rename landed.

A full board was published over it in between. The status ceremony reads
`test-results/latest.json`, whose schema carries a pass count, categories and
unit tests — **and no wall verdicts at all**. So the suite says ❌ at the end
of a run whose snapshot says 1294/1451, and every consumer downstream of the
snapshot sees only the number. Nothing in the publish path can even ask
whether a coherence wall was red.

This is the same defect one layer out, and it is the more dangerous layer:
the topology bug hid a wall from the runner, this one hides it from the
*record*. A wall that fires into a transcript a human may or may not scroll
to is a watcher again, and the fix is the same shape — the verdict has to
travel in the artifact the consumers actually read, not in the log of the run
that computed it. Neighbour on the artifact side:
[[frag-a-verdict-read-from-an-artifact-does-not-cover-the-run]], where the
artifact could not show the failure; here the artifact simply never carries
it.

## The fourth rung: a MARKER whose name claims a state it does not implement

Every rung above is about a guard that was meant to run. This one is about a
guard that was never going to, where the giveaway is a filename.

A test directory holding a `TODO` file is reported as `📝 TODO`, counted in its
own column beside passed and failed, and **returned from before the test is
executed at all**. It is a skip wearing the vocabulary of a backlog. Sixty-seven
test directories carried one when this was measured (2026-08-04), so the suite
has a third column that reads as work-in-progress and contains no verdicts.

The cost is specific and it is not the wasted coverage. The project's own
contributor guidance describes aspirational tests as the right move — add one
failing, *flip it to passing when the feature lands*. That promise needs the test
to RUN and go green on its own. A `TODO` test cannot flip: it produces the same
cheerful `📝` the day the feature ships as the day it was filed, and the only
thing that ever changes it is a human remembering to delete the marker. So the
mechanism that exists to track intended work is the one thing guaranteed not to
notice the work being done.

This extends the belief's existing line about comments — "'Blocking' in a comment
is a claim about intent, never about reach" — one step, and the step matters:
**a marker's NAME is that same unchecked claim, and it is more convincing than a
comment**, because a file called `TODO` in a directory of markers reads as
machinery rather than as prose. Nobody re-reads topology; nobody re-reads a
filename's semantics either.

- **Ask of every marker what state it asserts and what the runner does with
  it.** `SKIP` and `TODO` differing only in which counter increments is a
  distinction with no consequence, presented as two categories.
- **An aspirational test's whole value is that it is RED.** Red is the state that
  flips by itself, that shows up in a regression count, and that a reader can
  act on. Choosing a label that suppresses execution to keep the board tidy trades
  the one property the test was created to have for the appearance of not having a
  problem.
- **The falsifier fired.** `scripts/todo_sweep.sh` re-runs every TODO-marked
  test and reports PROMOTABLE (passed *and* pins something). The "nothing
  found does" sentence is no longer true. The marker still does not flip on
  the board — that half stands — but parked work is now *drivable*, which is
  the property `std/todo` named: a residual is real when something can run
  and decide it.

## The fifth rung: a failed column nobody can act on is also a skip

The fourth rung's other sentence — "an aspirational test's whole value is that
it is RED" — assumed `failed` was a short list a reader could treat as fire.
A published board of 98 never-green failures trained everyone to ignore the
column. Compiling them every ceremony run re-asserted the failure and nothing
about the explanation (`frag-a-red-pin-is-unfalsifiable-documentation`).

So the unignorable-red strategy for *never-shipped* pins is itself a watcher
off the path that matters: the next action. Those pins park as `TODO` and
the sweep is the driver. `failed` is reserved for:

- **regressions** — green in the snapshot window, then not
- **living diagnostic lies** — a wall fires, the pinned message is false
  (`330_124`, `370_020`)

Inverted `must-error-passed` holes are owed, not regressions: the wall never
existed on the boards we have, so they park too. Existing TODO crud (the
pre-2026-09-07 pile) is a separate pass — parking is not a licence to
stop reading those files.

## The sixth rung: a fail-soft step that names the WRONG cause

Every rung above lost a message. This one delivered one, and lost it anyway.

A full board ends by pushing its snapshot to the koru brain (`ctx patch
test-run`), deliberately fail-soft so a missing sink never fails the run.
Measured 2026-09-17, by hand, during a ceremony: the line it prints is
`⚠ Brain push failed: (node:…) [DEP0205] DeprecationWarning: module.register()…`
— and Node versions are a red herring. `ctx` runs through `tsx`, so the warning
is the FIRST line of stderr on every invocation, and the script reports the
first line. The actual failure was last: `Error: PATCH …/nodes/test-run → 500
Internal Server Error`.

**The channel is dark, and has been.** A synthetic patch passes at 256 KB and
fails at 512 KB; the board's own snapshot patch is ~650–700 KB. So every board
since the snapshot crossed that size has printed a warning, moved on, and left
the brain's `test-run` node holding an older board. A consumer asking the brain
"what is the board right now" has been reading whatever era last fit.

**What this rung adds to the belief.** Rung one was reach, rung three was the
record; this one had both and still lost the message. A *cause* is part of a
report, and a wrong cause is worse than no cause, because it is
actionable-looking: "DeprecationWarning" reads as housekeeping, "500 on a 700 KB
patch" reads as a limit to fix. The fail-soft POLICY is not the defect — its
whole point is that a missing sink never fails the board — the defect is that
nothing owns the question the policy leaves open: *did the board reach every
sink, and if not, why?*

- **A wrapper reports the child's failure, not its first stderr line** — that
  line is the runtime's chatter. Same family as the backend's refusal-vs-crash
  split in `backend.zig` (a misleading rendering of an already-delivered
  diagnostic): noise about the wrapper, presented where the failure belongs.
- **A fail-soft step with no consumer on its failure path is a watcher**, and
  rung five is what watchers become.
- **Open, and it is a design call nobody has made:** the payload is known
  rejected — shrink what the brain keeps (summary + a pointer to the snapshot,
  which git already holds) or raise the endpoint's limit. Until one lands, the
  node carries the real summary plus an explicit note that the data was
  withheld, rather than a compact stand-in board (a stand-in would be the
  fallback this repo bans).

## The seventh rung: the publish step itself was off every path

Rung six asked *did the board reach every sink*. Measured 2026-09-22: no.
The site's status pipeline (`aggregate-history` folds koru's snapshot into
`history.json`; `post-status-if-changed` compares counts against what
Discord last broadcast and posts on change) had not been invoked since
Sep-20. Three boards ran — 1820, 1828, 1832 — while the posted board sat
at 1818, and the gate's baseline logic was sound the whole time. The
failure was not reach-of-a-wall or a wrong cause; it was that **nothing
in the run called the step at all**. A ceremony that ends at `latest.json`
produces a measured board and calls it published.

This is the same topology defect one hop further out than rung one: the
watchers existed on a path nobody took; the publish existed on *no path*.
And it was invisible for the same reason — the gate's header documents an
earlier suppression bug, so "the feed is stale" reads as "the gate is
suppressing again" instead of "the step never ran."

- **The fix is the invocation, in the run itself** — `publish_board_to_site`
  in `run_regression.sh`, wired to the same full-run gate as the snapshot
  write, on BOTH run paths (parallel exits early; it gets its own call —
  rung one's exact pattern, applied to the step being added, not
  retrofitted after).
- **A missing sink is a skip; a failed publish is loud.** The step warns
  on failure and never fails the run — the fail-soft policy rung six
  defended, now with the question it left open owned: the warning is the
  consumer of the failure path.
- **"Posted" needs a reachable definition.** Before this, "the board was
  published" meant somebody remembered a second repo's script. Now it
  means the run ran — the only claim the suite can actually back.

## Open

Whether the other end-of-run steps that parallel mode skips matter as much. The
snapshot write and test-index generation are already gated on a full run in both
paths; nothing else was audited when this was found, and a second pass over what
diverges between the two paths has not been done.

Whether the ceremony consumes the sweep (PROMOTABLE on the snapshot) or
`--todo-sweep` stays a side path. Parking without a consumer repeats rung
four under a tidier name.

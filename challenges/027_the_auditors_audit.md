---
challenge: the-auditors-audit
kind: frame
status: standing
yields: a dead or drifting enforcement path removed or repaired, each landing as a runnable artifact — a cut with its comment, a drift check, a tombstoned signal, a pinned measurement
family: correctness
created: 2026-09-26
---

*Walker context — the census that earned this frame. The discipline machinery
was read end-to-end on 2026-09-26 (`hooks/`, `invariants/`, `signals/`,
`challenges/`, `models/commit_cadence/`), and the finding was: **the enforcement
layer has no enforcer.** Every other organ has a frame — parser `001`, suite
`005`, walls `017`, refusals `024`, transforms `025`. The gates, hooks, signals,
and frames that hold all of that up are audited by nobody, and they rot the same
way everything unaudited rots.*

*Measured that day, as proof the organ needs watching: the post-commit faucet
carried a queue leg that **could not fire** — commit-msg forces a belief-class
signal to stage its concept in the same commit, and the queue leg skipped
exactly those commits. Dead code that looked live for a month. **50 of 125
signal files** (40% of the vocabulary) were auto-registered orphans carrying
`refine me`, and the register-on-miss path minted them `membrane: false` — so a
commit declaring `Signal: evolve` or `Signal: corrected` on belief work slid
past the garden-in-place interlock entirely. Two distinct frames shared `010`.
`gate-load-failure-was-silent` is the canonical lesson: `gate.py` once parsed
zero rows from a failed listing, reported "no invariants declared", and exited
0 — commits passed unjudged while the gate reported green.*

*The concepts behind the frame:
`concepts/frag-compliance-is-counted-with-the-enforcers-predicate` is the
method — audit with the machinery's own predicates, not a reading of them —
and `concepts/frag-a-gate-that-fails-conservative-is-invisible` is why the top
rung is a gate that fails open.*

---

## The brief (sealed — you are the contestant)

**Audit one leg of the discipline machinery. Land what you find as a runnable
artifact, not a report.**

The legs, any of which is a valid pick:

- **`hooks/`** — does each tracked hook match its installed `.git/hooks/` copy?
  Does every code path in it still have a caller that can reach it? Do the
  comments describe what the code does *now*?
- **`invariants/`** — can every `check:` row in `invariants.kz` actually run
  today (its binary exists, its scope resolves)? Does any judged row fail open
  — report green on an error path? Does `gate.py` still refuse on an empty or
  failed manifest listing?
- **`signals/`** — orphan rate (`auto-registered orphan` count / total files).
  Does each `membrane: true` file still earn it? Do tombstones point at live
  canonicals? Does commit-msg's near-miss gate cover the names history actually
  declares?
- **`challenges/`** — numbering collisions, `status:` fields that drifted from
  reality, walker-context measurements whose cited commits or counts no longer
  hold, catalog entries a replay cannot actually run.
- **`models/commit_cadence/`** — does `cc_live` still build and fire, or is the
  measured layer silently off?
- **Cross-repo reach** — `koru-libs`, `6digit-world`, installed copies of these
  hooks elsewhere: which version is live there, and does it match this source?

Return **1–3 findings**, each landed as its own commit: a dead path cut with a
comment naming the commit that parked it, a drift/reachability check added
where the machinery itself can enforce it, a signal refined or tombstoned, or
a stale measurement corrected with its fresh number cited.

A finding you measured but did not land is a lead, not a deliverable — park it
under leads with the evidence.

## The ladder — what enforcement rot costs

Rank by how loudly the machinery lies while reporting green:

1. **A gate that fails open.** The check runs, hits an error path, and reports
   green anyway — `gate-load-failure-was-silent` is the exemplar. Worse than no
   gate: it launders unjudged commits as judged.
2. **A dead path that looks live.** Code that cannot fire but reads as armed —
   the inbox queue leg. It teaches the next reader a topology that does not
   exist, and someone will rely on it.
3. **A leak in the vocabulary.** A signal name that bypasses the interlock it
   semantically belongs to (`membrane: false` minted onto belief-class names),
   or a register-on-miss that re-creates what the last drain removed.
4. **Drift between source and installed copy.** `hooks/` is tracked; `.git/`
   is not. An installed hook an edit never reached enforces the old rule while
   the diff says the new one.
5. **Rot in the catalog itself.** Collided numbers, stale walker measurements,
   a frame whose yields name artifacts that no longer exist.

## Where the findings are

**Run the enforcer's own predicate.** Do not read a hook and judge whether it
looks right — run it against a constructed input and watch what it does. A
commit with a `Signal:` name that minted as an orphan, a manifest listing that
returns no rows, a `membrane: true` signal on a commit staging no concept:
each is a probe the machinery has a defined answer for. The answer it gives is
the measurement.

**Diff source against installed.** `diff hooks/post-commit.cjs
.git/hooks/post-commit.cjs` — and the same check run against every repo these
hooks were installed into (`koru-libs`, `6digit-world`). Drift found this way
is a landed finding the moment you resync it.

**Count what the drain left.** `grep -l "auto-registered orphan" signals/*.signal
| wc -l` — the orphan rate is the vocabulary's own health metric, and it
re-grows the moment a commit declares an unlisted name.

**Check a walker measurement against the tree it cites.** Challenge prose cites
commits, counts, and pin names. Compile one. If the cited number moved, the
frame lies to its next replay — that is a finding, and the fix is the fresh
number.

## ⚖️ What a finding is not

- **Not a style pass.** A hook that works while being ugly is working. The
  target is machinery that reports a state different from the one it enforces.
- **Not new machinery for its own sake.** A check that guards nothing
  measurable is a wall for a wall's sake — `manifest-stays-enforceable` exists
  because the manifest grew past legibility; cite the recurrence that earns
  yours or park it as a lead.
- **Not a vibe about "should".** Every landed finding carries the measurement:
  the command run, the output quoted, the tree it ran against
  (`git rev-parse HEAD`).

⛔ **Do not weaken a gate to make a finding green.** If the honest fix is a
refusal the machinery should have had, add the refusal — never remove the
check that caught the rot.

⛔ **Do not touch `src/` or `koru_std/` here.** This frame audits the
discipline layer. A finding that lands inside the compiler belongs to `024`
or `017` — file it under the right frame.

## Ground yourself FIRST

- Read `hooks/commit-msg.cjs`, `hooks/post-commit.cjs`, `hooks/pre-commit`,
  `hooks/install.sh`, `invariants/gate.py`, `invariants/invariants.kz` before
  claiming anything is dead — a path is dead only when you can name why no
  caller reaches it (the inbox leg's epitaph: the interlock makes its commits
  always touch `concepts/`, which the leg then skips).
- `git log --follow` a hook before calling its behavior a bug — half the
  strange branches are measured-failure repairs with their commit named in a
  comment.
- Check `pgrep -fl "run_regression|zig build"` before any suite-touching
  verification.
- Commit hooks require `## World Model` and `## Membrane` sections.
  `--no-verify` is banned.

## Parked leads — measured 2026-09-26, awaiting a replay

- **Installed-copy drift check has no home.** Today `hooks/` and `.git/hooks/`
  matched, but nothing enforces it — a `diff`-or-warn step in `pre-commit` or
  a `check:` row is the natural landing, and the design question (which side
  wins on mismatch) is open.
- **The orphan vocabulary re-grows.** Register-on-miss still mints
  `membrane: false` stubs for any undeclared `Signal:` name; the tombstone
  convention (file stays, note points at the canonical, membrane mirrors it)
  was invented in the 2026-09-26 drain and has no enforcer — a `check:` row on
  orphan rate, or a near-miss-gate widening, would hold the line.
- **`membrane.json` is now declarative.** Nothing routes through it since the
  queue leg was cut; `install.sh` still writes it and the membrane skill still
  documents it. Whether the pointer should be retired cross-repo is a ruling
  question, not a finding.
- **`gate.py` reachability is unpinned.** `manifest-stays-enforceable` guards
  the manifest's size; nothing re-runs the empty-listing refusal
  (`gate-load-failure-was-silent`'s fix) as a standing check.

## What "done" looks like

- 1–3 findings, each a commit carrying the measurement (command + quoted
  output + `HEAD` it ran against) and the artifact (cut, check, tombstone, or
  corrected number).
- For each: its rung on the ladder, and why the artifact lands in the
  machinery itself rather than as prose about it.
- Leads: measured candidates you did not land, with evidence.
- Ruling questions: written, unanswered.

## Failure modes

- **Auditing by reading.** "This path looks dead" is unmeasured. Name the
  caller that can't reach it, or run the probe.
- **Deleting the archive.** `docs/inbox/pending.jsonl` is parked history, not
  dead code — cutting artifacts that recorded real events is destruction, not
  hygiene.
- **A check that checks nothing.** A drift check that never fires is the same
  class of lie it was built to catch; verify it fires on a constructed
  violation before landing it.
- **Weakening to pass.** See the ruling — the fix is a refusal, never a
  removal of the thing that caught you.
- **Scope creep into the compiler.** Findings in `src/` go to the frames that
  own them.

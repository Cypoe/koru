---
challenge: friction-corpus
kind: frame
status: standing
yields: every recorded refusal family lands in BUG/DIAG/DESIGN/DOC with evidence, a red pin, or a written ruling question
family: toolchain
---

*Walker context — the recurrence that earned this frame. On 2026-09-28 a side
session read `sessions.db` instead of guessing: every agent session against
koru has been quietly logging its own compiler refusals, verbatim, with the
offending source line attached. One query turned it into a corpus:*

```
2,081 diagnostics · 52 sessions · 5 repos (systemic view: 1,523 · 50)
KORU010 stray continuation        369  (71 teach-miss — the agent guessed)
PARSE006 label required           280  ( 0 teach-miss — taught, fought anyway)
KORU161 store semantics           232  (33 teach-miss — invented wrong models)
PARSE003 chain grammar            172
KORU022/021 branch coverage       177
KORU030 phantom state             119
PARSE005 label forbidden (pun)     85
```

*Two grammar decisions — line-oriented chains and the label↔pun seesaw — carry
~45% of every refusal ever recorded. Two bugs were confirmed and pinned red the
same day (`100_087`, `690_353`). One transcript-learned "rule" was debunked by
a scratch compile (comments between `|>` steps are legal — the corruption is
only inside blocks). The corpus cost nothing to produce and keeps growing:
every koru session appends to it.*

*`010` mines the board's red. `018` mines the green by hand. This frame mines
the **recorded telemetry** — the refusal history the compiler has already
written, ranked by how often it fires and whether the message taught anything.*

---

## The brief (sealed — you are the contestant)

The corpus lives at `friction/` in this repo. Start there:

```
python3 friction/friction.py scan          # rebuild from sessions.db
python3 friction/friction.py hist          # code × frequency × teach-miss
python3 friction/friction.py hist --without org:COCPORN,repo:ogun  # systemic view
python3 friction/friction.py lookup KORU161  # every occurrence + the fix that followed
python3 friction/friction.py pitfalls      # ranked digest
python3 friction/friction.py report        # regenerate corpus.md
python3 friction/timing.py               # refusal episodes → time-to-green per code
```

Corpus membership is **invocation-scoped** — a row counts when the call ran
`koruc`/`run_regression` or the cwd is koru-family, so compiles fired from
`the-man`, `/tmp`, or `korulang_org` all land. Every row carries `repo`,
`org`, `via`, `session`, `cwd` — filter, don't delete. **Work the systemic
view** (`--without org:COCPORN,repo:ogun`): a greenfield game's refusals
measure a confused newcomer, not the language. Under it, KORU010 is still #1
(345, 71 teach-miss) but KORU161 is 126 not 207 and PARSE006 55 not 235 —
half the old headline numbers were one game session.

`corpus.json` holds every row: diagnostic, `file:line`, the offending source,
the agent's next action, and a teach-miss flag (the agent's follow-up was a
guess or a wrong model rather than a rule). `corpus-timing.json` holds 213
resolved refusal **episodes** (a run of erroring `koruc` calls ended by a
clean compile) with wall-clock dwell: overall median 0.5 min, but the tail is
the finding — one KORU010/KORU030 episode burned 42.5 min, KORU161's worst was
9.4 min across 5 failed compiles, KORU104's median episode is 4.3 min with a
12-fail single episode, KORU037's mean is 17.3 min on 3 episodes. Episode dwell attributes the whole burst's duration to
each code in it — co-occurring codes share credit, so read per-code dwell as
directional and episode rows as the truth.

**Take the top families by corpus share.** For each, in order, do four things:

1. **Re-measure against the current tree.** The corpus is history; the compiler
   has moved. Write the minimal repro and compile it *this session*. Three
   states: **blocker** (still refuses — quote it), **not a blocker** (compiles,
   or a passing test is that join), **unmeasured** (you did not compile it —
   stop talking). A transcript's learned rule is a hypothesis, not a fact.
2. **Classify.** Every verified family lands in exactly one bucket:
   - **BUG** — compiler/emission/diagnostic factually wrong → pin red
     (`tests/regression/`), then fix in `src/` with a green control.
   - **DIAG** — refusal correct, message wrong or unteaching → fix the
     message; the teach-miss rows tell you what it should have said.
   - **DESIGN** — deliberate rule, cost is program shape → write the ruling
     question with the measured numbers. Do not answer it.
   - **DOC** — real rule, exists only as error strings → generate the doc
     surface (see below).
3. **Use the teach-miss axis as the fix-vs-teach sort.** Fires often +
   agent learns anyway (PARSE006: 0/235) → the *rule* is the friction — that's
   DESIGN. Fires often + agent guesses (KORU161: 33/207; KORU010: 69/337) →
   the *message* is the friction — that's DIAG. Both rankings come free from
   `hist`.
4. **Feed the corpus.** Your own session's refusals land in `sessions.db`.
   Before signing off, re-run `friction.py scan` so this replay is measured
   into the corpus it just mined — the frame that measures itself.

## The DOC deliverable is generated, never handwritten

The negative space is already machine-pinned: `src/errors.zig` holds 116 codes,
every one doc-commented; 261 `MUST_ERROR` tests pin refused programs. But only
**39 codes appear anywhere in the suite** in emitted-diagnostic form, and the
tutorial covers none of it. The DOC deliverable for a family is a *generated*
surface — error catalog (`code → enum comment → message template → pinning
tests`), refusals index (walk `MUST_ERROR` dirs), or doc-tested tutorial
sections — not a hand-edited markdown file that will rot.

## Known-open items (measured 2026-09-28, re-verify first)

- ~~`PARSE006` hint always names the first parameter~~ — **fixed** (`2b996acb7`,
  pin `100_087` green). Kept as the frame's proof it works.
- ~~`// comment` inside a `std/store:new` schema block corrupts emission~~ —
  **fixed** (same commit, `struct_literal.zig::splitFields` strips line
  comments; pin `690_353` green).
- `KORU010` "stray continuation" — split by shape (345 systemic rows):
  **308 of 326 stray-continuation rows arrived in bursts ≥3** — one severed
  chain orphans every continuation line below it, each firing an identical
  unteaching error. DIAG fixed: orphan runs now collapse to one diagnostic
  naming the run's span and the separator (`blank lines end a chain — the
  construct at line N cannot be continued across one`; pin `210_307`).
  Open DESIGN ruling: comments between chain steps are trivia (210_239) but
  blank lines end the chain — agents write blanks to organize long flows and
  the corpus says they never learn the asymmetry. Should blank lines inside
  a `|>` chain be legal? (bursts = ~95% of this family's volume; the cascade
  fix measurably teaches the rule in the meantime — re-run `hist` to check
  teach-miss delta.)
- `KORU161` — the stdlib contract-refusal umbrella: ~421 refusal sites across
  46 contracts (`store`, `supervisor`, `pump`, `channel`…). 128 systemic rows,
  ~30 of them pin-authoring probes (`kind:pin`), not organic friction.
  The "never teaches" claim measured half-wrong — most sites teach already.
  One real DIAG gap, **fixed**: `std/store:query` collapsed three states into
  "unknown plural store" — genuinely unknown name, query-before-declaration,
  and capacity-1 *value* store. The value tier is detected via the
  `__store_write_<name>` marker (same idiom `store.stored.kz` uses) plus an
  untransformed-`new` ordering probe; the new message names the tier and the
  two right spellings (`game.<field>`, `std/store:watch(game)`;
  pin `690_354`). DOC shipped: `docs/refusal-matrix.md` —
  `friction/contracts.py` walks every `koru_std` refusal site, groups by
  contract, ranks by corpus volume.
  Open DESIGN ruling: keep one umbrella code, or split per contract so codes
  rank families directly in `hist`?
- `KORU021` leaks `std.io:print.impl` internals into user-facing errors.
- DESIGN questions raised and not ruled: guarded multi-arm `! query` sweeps;
  calls in argument position (could be a lowering); the label↔pun seesaw;
  `|>` after an arm-bodied step; rows as tor params; store plurality visible
  in the spelling.
- `ogun`'s build layer is a sibling friction surface (scons compiles a *copy*
  of `ogun.mm`; `template_debug` emits an empty dylib) — same genus, out of
  scope for this frame's `src/` work but worth a finding note.

## What "done" looks like

- Every family with ≥25 corpus occurrences re-measured this session and
  classified, with the repro quoted.
- BUG/DIAG items carry a red pin *before* the fix; the pin goes green by the
  compiler changing, never by the pin moving.
- DESIGN items are written ruling questions carrying their corpus numbers —
  the deliverable, not a failure.
- At least one generated doc surface exists where `hist` says teaching fails
  most — shipped: `docs/refusal-matrix.md` (contract × refusal site × corpus
  volume). Next candidate: code catalog for the top `hist` family.
- `friction.py scan` re-run; the frame's own refusals are in the corpus.
- A count of how many families shared a mechanism — today ~29% of everything
  is the line-oriented chain; if your count finds one mechanism dominant,
  that outranks any individual fix.

## Failure modes

- **Trusting the transcript.** Session narration encodes hypotheses, several
  of them wrong (measured today). Compile before you classify.
- **Fixing the consumer.** A workaround in a `.k` file that dodges the
  refusal is the banned route-around — the gap is the deliverable, in the
  compiler's own terms.
- **Inventing a spelling** to close a DESIGN item. Write the question.
- **Greening by moving the pin.** Banned outright.
- **Counting by a plausible predicate.** Use the harness's own predicate
  (`regression_lib.sh`) and the corpus's own rows — two scoping counts were
  already wrong once each today.
- **Misreading `taught` as per-diagnostic truth.** When one compile emits N
  errors, the next assistant narration attaches to all of them — read the
  burst, not the single row, before citing a teach-miss.

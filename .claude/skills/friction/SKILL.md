---
name: friction
description: Mine recorded koruc refusals from session journals into a searchable corpus — frequency, teach-miss rate, and time-to-green per diagnostic. Use when triaging compiler friction, improving diagnostics or messages, deciding fix-vs-teach for a language rule, or after a koru-heavy session so its refusals join the corpus. The corpus lives in friction/ and is regenerable — never trust a transcript's learned rule without re-measuring it.
---

# Friction — the refusal corpus

Every agent session against koru logs each `koruc` refusal — diagnostic,
offending line, what the agent did next — into `sessions.db`. `friction/` turns
that into the compiler's measured negative space.

## The tools

```sh
python3 friction/friction.py scan        # rebuild corpus.json from sessions.db
python3 friction/friction.py hist        # code × frequency × teach-miss rate
python3 friction/friction.py lookup KORU161   # every occurrence + what followed
python3 friction/friction.py pitfalls    # ranked digest
python3 friction/friction.py report      # regenerate corpus.md
python3 friction/timing.py               # refusal episodes → time-to-green
```

`scan` is safe to run anytime and should be re-run after any koru-heavy
session — the corpus grows for free as sessions accrue. Membership is
**invocation-scoped**: a row counts when the tool call ran `koruc` /
`run_regression`, or when the cwd is koru-family — so a compile fired from
`the-man` or `/tmp` still lands. Cwd allowlists miss real refusals; the
compile is the event.

## Provenance — filter, don't delete

Every row carries `repo`, `org` (resolved from the repo's own git remote),
`session`, `cwd`, and `via` (`koruc` / `board` / `ambient`). All read verbs
and `timing.py` take filters:

```sh
--without org:COCPORN,repo:ogun     # the systemic view — compiler + mature
                                    # consumers; game-jam and site noise out
--only repo:kopium                  # one consumer's slice
--without via:board                 # drop run_regression-captured rows
```

Greenfield and site sessions are real telemetry — they stay in the corpus —
but their refusals measure a confused newcomer, not the language. **The
working backlog is the systemic view**: `hist --without org:COCPORN,repo:ogun`.
Re-ranking under it matters — KORU161 is 207 rows unfiltered but 126
systemic; PARSE006 was 235 but 55 (half of it was one game session).

## The triage rubric

Every friction family lands in exactly one bucket — the bucket picks the fix:

- **BUG** — compiler/emission/diagnostic factually wrong → pin red in
  `tests/regression/`, fix `src/` with a green control.
- **DIAG** — refusal correct, message wrong or unteaching → fix the message;
  teach-miss rows tell you what it should have said.
- **DESIGN** — deliberate rule whose cost is program shape → write the ruling
  question with the measured numbers. Never answer it yourself.
- **DOC** — real rule that exists only as error strings → generate the doc
  surface; never hand-maintain a static copy.
- **ENV** — deleted worktree, native-build, external tool → discard.

## The sort axes

- **Frequency** — how often the refusal fires (corpus share).
- **Teach-miss** — how often the agent's follow-up was a guess or a wrong
  model. High miss → the *message* is broken (DIAG). Zero miss but high
  frequency → the *rule* is fought but understood (DESIGN).
- **Dwell** — wall-clock from first refusal to next clean compile
  (`timing.py`); the tail matters more than the median.

## Hard rules

- **A transcript's learned rule is a hypothesis.** Compile the claim against
  the current tree before classifying. The corpus has already caught a
  confidently-stated wrong rule (comments between `|>` steps compile fine —
  only comments *inside* blocks reached a scanner).
- **Never fix the consumer.** A workaround in a `.k` file that dodges the
  refusal is the banned route-around — the gap is the deliverable, in the
  compiler's own terms.
- **Attribution caveat:** when one compile emits N diagnostics, the agent's
  next narration attaches to all of them — read the burst, not the row.
- **The loop is the product.** Refusals → corpus → triage → compiler fix →
  new telemetry. `scan` after koru-heavy sessions is what makes it a
  flywheel rather than a snapshot; the challenge below is its standing
  generator.
- The standing generator that replays this discipline is
  `challenges/028_the_friction_corpus.md`.

Belief: `concepts/frag-session-journals-are-a-refusal-corpus.md`.

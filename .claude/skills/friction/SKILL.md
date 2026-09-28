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
python3 friction/timing.py               # refusal episodes → time-to-green
```

`scan` is safe to run anytime and should be re-run after any koru-heavy
session — the corpus grows for free as sessions accrue.

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
- The standing generator that replays this discipline is
  `challenges/028_the_friction_corpus.md`.

Belief: `concepts/frag-session-journals-are-a-refusal-corpus.md`.

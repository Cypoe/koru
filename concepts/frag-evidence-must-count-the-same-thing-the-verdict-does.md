---
type: belief
id: frag-evidence-must-count-the-same-thing-the-verdict-does
provenance: draining the diagnostic-code registry 2026-07-26 — `confirm KORU123` reported 506 pinned test references against zero real ones, because the evidence command and the authoritative check defined "pinned" differently
ts: 2026-07-26
---

# When a tool measures a word two ways, the operator gets the looser one (belief)

`registry_check.zig` holds two surfaces. The watcher computes PINNED from test
expectation files — `expected*` and `EXPECT` — which is what a pin is. The
`confirm <CODE>` battery, the step the drain playbook makes mandatory before any
disposition, greps every file under `tests/regression`. Each test directory also
holds build residue: an emitted Zig file and an AST dump carrying the compiler's
own `ErrorCode` enum. So every declared code appeared pinned hundreds of times.

Both numbers were computed correctly. They were answers to different questions
wearing one name.

## Why this is worse than being wrong in general

The over-count did not merely mislead, it **argued for the opposite
disposition**. The drain asks: is this code an unwired bug, or unbuilt semantics
to reserve? "PINNED: 506" says the suite depends on this heavily, so wire it.
The true evidence — nothing pins it — says the opposite. A tool that inflates a
number in the direction of one verdict is not noisy; it is a bad advocate, and it
is the surface the operator was told to trust *because* it is the detailed one.

Detail reads as authority. Of two disagreeing surfaces, the one printing file
paths and line numbers wins the operator's belief, whether or not it is the one
the verdict is defined against.

## The same shape at the judge-input layer (2026-10-08)

The git-gate's judged rows got the same defect from the other side: not two
surfaces counting differently, but one judge fed *more than the question
asked*. `the-construct-is-a-tor` asks "does this diff *add* prose naming the
unit 'event'" — and was handed `git diff --staged` with three lines of
unchanged context around every hunk. A diff whose added lines carried zero
'event' prose judged VIOLATION/CLEAN/VIOLATION on identical input (p≈0.55),
because the context lines around the change were saturated with the legacy
word — the judge could not tell addition from adjacency. The looser reading
the operator got was a coin-flip verdict on a clean commit.

The fix is the same as the registry fix: make the evidence set *be* the
verdict's set. `judge-additions` narrows a row's state to added lines plus
file/hunk headers — the slice of the diff the rule literally asks about.
"Does the diff remove/weaken" rows keep the full state; the tag exists so
each row's input matches its question rather than inheriting the generic one.

## What follows

- **One definition per word, shared by both surfaces.** Not two functions that
  agree today — the same filter, so they cannot drift apart later.
- **Evidence and verdict must be derived from the same set.** If the check says
  DEAD and the evidence says heavily-pinned, at most one is answering the
  question, and no amount of reading either in isolation reveals which.
- **Build residue inside the corpus is a scanning hazard, not just clutter.**
  Generated artifacts under `tests/regression` contain the compiler's own source,
  so any scan for compiler tokens finds itself. Filter by what a thing *is*, never
  by where it sits.

Family: [[frag-a-check-that-cannot-match-reports-clean]] (a check that cannot
match reports clean) and [[frag-a-check-must-not-mutate-what-it-inspects]]. The
shared thread is that a check's output is trusted in proportion to how much work
it appears to have done, and none of these three failures look like failures.

## Open

Whether the other `confirm` rows have the same defect. POLICY greps `docs` for
bare code mentions and EMITTED greps `src` and `koru_std` for `.CODE` and
`error[CODE]`; neither was audited against the authoritative sets, and EMITTED is
the one a wiring decision leans on hardest.

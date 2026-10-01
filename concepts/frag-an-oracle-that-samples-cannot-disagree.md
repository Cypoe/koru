---
type: belief
id: frag-an-oracle-that-samples-cannot-disagree
provenance: 2026-08-03 — the ECS harness validated cross-implementation equivalence by summing the first sixteen rows in iteration order; widening it to the full corpus took agreeing scenarios from three of ten to nine of ten and exposed three defects in the same run. Evolved 2026-10-01: the fuzzing session found the endpoint case — an emit-diff over a program-independent artifact that cannot disagree by construction.
ts: 2026-10-01
---

# An oracle that samples cannot disagree, and an oracle that cannot disagree is not evidence (belief)

A benchmark's timing number is only meaningful if the implementations did the
same work, and the only thing that establishes that is the oracle. If the oracle
inspects a sample, it can only ever prove the sample matched — and a sample
small enough to be cheap is small enough to agree by accident.

The failure is not that a weak oracle reports wrongly. It reports *nothing*. It
sits in the harness looking like diligence, and every number published beside it
inherits a confidence it never earned.

## How it got there, which is the part worth remembering

The sink began life as an **optimizer barrier** — something to consume the
computed values so the backend could not delete the workload. A handful of
elements is ample for that job. Then it was read as a **correctness oracle**,
which is a different job with a different size requirement, and nobody re-sized
it because nothing looked broken.

That is the general shape: a mechanism built for job A, later relied on for job
B, where B's requirements are strictly stronger and B's failure mode is silence.
The rename never happens, so the review never happens.

## The tell, and it is available for free

**Two reference implementations that disagree with each other cannot arbitrate a
third.** When the two anchors' sinks differed from one another, that was already
proof the protocol was broken — no knowledge of the third implementation
required. Nobody looked, because each anchor was only ever compared against the
implementation under test, never against its peer.

Any time there are two or more references, check them against each other first.
It is the cheapest possible validation of the instrument and it needs no
hypothesis about what might be wrong.

## What an honest oracle bought immediately

Widening to a full-corpus, order-independent aggregate did not merely raise the
count of comparable rows. Every remaining disagreement became a *diagnosis*,
because a full-state number differs by an amount that names its cause:

- a reference was doing one extra frame of work before the timer started, and
  the sum was over by exactly one frame's worth of motion;
- one port's sink read the whole corpus where the workload touched a filtered
  subset;
- one reference's "empty" system was emptier than the others', which no
  hardcoded sink could ever have surfaced.

None of these were suspected. All three fell out of the same run. **A good
oracle does not just say no — it says by how much, and the residual is the
bug's signature.**

## The order-independence requirement, which is separate and easy to miss

A full-corpus check is still worthless if it depends on visit order, because
implementations legitimately iterate differently. The aggregate must be
commutative — integer accumulation, not float, since float addition is not
associative. Truncating floats into that accumulation is a deliberate trade: it
tolerates last-bit differences between languages while still catching a missed
row, a wrong row, or a wrong count.

## The endpoint case — the artifact contains no variable (2026-10-01)

Sampling is one way an oracle loses the ability to disagree; there is a
stronger one. An oracle built on an artifact that does not contain the quantity
under test cannot disagree *by construction* — sample size zero, not small.

The sibling-fuzzer's emit-diff was exactly this: `koruc -o` writes a
program-independent backend driver to the `-o` path, byte-identical for every
input, so diffing it "verified" nothing for any program ever run through it. It
reported clean on a changed string literal, which is the bisect frag's sabotage
check turned inward on the oracle itself: a change that must be visible was
not, so the artifact under comparison was the wrong one. The real payload
(`program.ast.json`) landed beside the input file, not at the flag.

The generalization worth carrying: before trusting any differential oracle,
diff it against a deliberate perturbation and require a diff. An oracle that
cannot fire is worse than no oracle — it reads as coverage.

## Open

Where the line sits between "the ports disagree because the oracle is weak" and
"the ports disagree because they implement different workloads". One scenario
still diverges after the oracle was fixed, and that residue is the interesting
kind — it says the three implementations are not doing the same thing, which is
a specification question the oracle correctly refuses to answer.

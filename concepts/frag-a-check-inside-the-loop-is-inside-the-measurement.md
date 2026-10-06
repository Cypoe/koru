---
type: belief
id: frag-a-check-inside-the-loop-is-inside-the-measurement
provenance: 009_effect_chaining — a fires++ parity counter inside the
  measured ops arm made generated (81ms) slower than virtual (19ms);
  the counter's serial dependency was the benchmark
ts: 2026-10
---

# A check inside the loop is inside the measurement (belief)

A benchmark needs a correctness control — proof the work under
measurement actually ran. The failure mode is reaching for the
instrument, not the result: `fires++` on a shared static inside the
measured arm, "proving" each hop fired. It proved it — and it also
became the program. Eight serialized read-modify-write hops on one
static per element is a dependency chain with a latency floor; the
generated arm measured the counter, not the dispatch, and reported 81ms
against a handwritten loop's 8ms for what was really ~15ms of work.

The control didn't need weakening — it needed moving to where checks
are cheap and instrumentation is impossible: the consumed result. Every
arm in that benchmark moves the same values through the same stages, so
the sum has a closed form (`N(N-1)/2 + N·K`). A stage that never ran
produces a wrong sum. Checking the sum after the loop is a *stronger*
parity gate than counting fires — fires could pass while a stage
miscomputed — and it costs zero inside the measurement.

Sibling of
[[frag-a-cost-the-optimizer-deletes-was-never-there]] — that belief is
about a mock manufacturing a cost the real program doesn't have; this
one is about the harness manufacturing a cost inside the real program.
Same family: the instrument is part of the artifact under test, so
verification belongs on the consumed output, never on the measured path
itself.

## What follows

- Parity/control logic lives on the *result* — a closed-form sum, a
  checksum of consumed values, an output diff. If the check requires a
  write inside the loop, it is a workload change, not a check.
- When a measured arm looks anomalously slow, suspect the control
  before the artifact — the anomaly shape (serial, per-hop, only on the
  instrumented arm) names it.
- "The arm ran" is proved by the result being right. A counter that
  proves presence but not correctness is weaker *and* slower — the
  worst trade.

2026-10-14 — the asymmetry is the tell, and it applies at the *arm*
boundary too. 012's `collect` shim checksummed inside the timed loop —
`hits += 1; chars += s.Length` per element, two static stores and a
length read — while every comparator arm ran its checksum after the
stopwatch. The generated arm was timing bookkeeping nobody else paid:
not a workload the task contains, but a workload only one arm carried.
`collect` reduced to `results.Add(s)` and the generated arm fell from
1695ms to ~1470–1480 on a calm box — inside the pack, under LINQ. The
extension to the rule: a check inside the *shared* loop is a workload
change; a check inside *one arm's* loop is a rigged race — the verifier
must be identical in *placement*, not only in arithmetic, or the
measurement is comparing two different programs.

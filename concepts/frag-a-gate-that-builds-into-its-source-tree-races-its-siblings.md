---
type: belief
id: frag-a-gate-that-builds-into-its-source-tree-races-its-siblings
provenance: 2026-10-27 — 310_142 c-refine failed under the parallel 310 run
  with `unknown module prefix 'FlowKernel'` and passed alone; the gate was
  deleting FlowKernel.olean out from under a sibling invocation.
ts: 2026-10-27
---

# A gate that builds into its own source tree races its siblings

`semantics_gate.sh` compiled `FlowKernel.olean` inside `verify/semantics/`,
ran its corpora against it, then `rm -f`'d the artifact on exit. Correct
single-threaded. Under `./run_regression.sh`'s default parallelism two
tests sharing the gate overlap: one's cleanup deletes the `.olean` while
the other is mid-`import`, and the failure lands on the *innocent* test —
"unknown module prefix," nowhere near a compiler defect. The shared
`.check.err` scratch file is the same hazard with a quieter symptom.

This is the same shape the profiler pins taught
(`frag-profiler-pins-race-on-global-trace-path`): parallel harness + one
shared artifact path = a race, and `--parallel 1` is the workaround that
hides it instead of fixing it. The gate variant is worse than the
profiler's: the artifact lives inside the tracked source tree and the
cleanup actively *removes* state a sibling may be reading, so the race
corrupts rather than merely overwrites.

The rule: a gate's derived artifacts belong in per-invocation scratch
(`mktemp -d` + `trap` cleanup), never in the directory the sources live
in — even when the source dir is the "natural" build location. Corpus
arguments must already be absolute paths for this to be free, which they
were: the fix cost eight lines because the contract was honest elsewhere.

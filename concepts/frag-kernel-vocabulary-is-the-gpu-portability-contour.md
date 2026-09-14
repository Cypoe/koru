---
type: belief
id: frag-kernel-vocabulary-is-the-gpu-portability-contour
provenance: session 2026-09-14 — signal surface design walk; the contour fell out of asking where a signal tick should run
ts: 2026-09-14
tags: [koru, kernel, store, gpu, portability]
---

# Kernel's restricted vocabulary is the GPU-portability contour, not a missing-feature list (belief)

`std/kernel`'s body grammar is deliberately small — `self` elementwise over
rows, `pairwise` over pairs, `step` for substeps; no general loops, no host
calls — because the kernel is designed to be **GPU-portable for certain
payloads**. The restriction is the contract: what a kernel body can say is
bounded by what can lower to lanes someday. The cut-off is intentional, and
the boundary is where portability stops.

That reframes what looked like gaps. "No loops inside kernel bodies" (named
by ponkatris, blocking SAT narrowphase) is not a defect to close — it is the
wall holding. Work that cannot port — variable-length loops, dynamic
allocation, evented control flow, per-instance history windows — belongs to
`std/store` plus ordinary flows by design: lifecycle, presence, membership.
The contour partitions the work, it does not rank it.

The partition, applied:

- **kernel-shaped (ports to lanes):** fixed-shape arithmetic over rows —
  integration, impulse math, distance-guarded filters. `pairwise` is serial
  N²/2 today but elementwise-parallel *in shape* — the headroom is in the
  vocabulary, waiting.
- **store/flow-shaped (CPU by nature):** insert/take lifecycle, per-client
  sessions, replication assembly, windowed/ring-buffer state.
- **The one control-flow idea that ports:** presence/absence — a `void` lane
  is a predication mask, classic GPU semantics. Missing data lowers to an
  inactive lane, not a branch.

Consequence for anything that wants to *be* kernel-runnable later (signal
models are the case at hand): author the compute in kernel vocabulary from
the start — masked `if`, elementwise, no loops — so the portable subset
actually ports when the native path exists. Portability is an authoring
discipline upstream of any backend.

# Handoff — union-tag dispatch weight in emitted flow loops

**Objective:** make `#loop` / flow continuation dispatch emit register/jump
dispatch instead of materializing union tags through memory. This is a
general emitter improvement — every flow loop in every program pays it,
not just this benchmark. Fix lands in `src/`, never in emitted artifacts.

**Tree pin:** authored against koru main @ 714b76d3c (2026-10-01).
Verify file:line refs against current HEAD before trusting them.

## Verified facts (evidence, not narration)

The benchmark: 10M u64 messages, 1 producer thread + 1 consumer thread,
capacity-256 Vyukov MPMC ring, checksum-validated. `input.kz` (Koru) vs
`baseline.zig` (hand-written Zig), both `std.heap.page_allocator`-allocated.

- **Ring loop instruction-identical.** objdump of `koru_output` vs
  `zig_output` shows the same acquire-load/CAS/release-store sequence.
- **Producer thread instruction-shape-identical.** Both `entryFn`
  functions have the same branch skeleton at the same offsets.
- **Consumer carries real debris:** ~9 flag-byte ops (`strb`/`ldrb`/`tbz`)
  per unrolled pair of iterations vs 0 in Zig. These are union-tag stores
  and constant-folded tag tests surviving instruction selection.
- **The debris is ~free in this workload.** A hand-fused emitted variant
  (4 flag ops vs Zig's 3) ran the same wall time. Emitted weight, zero
  measured cost here — but "free" is workload-dependent.
- **Head-to-head: Koru won 31/80 interleaved runs**; mins within 2%
  (109.9 vs 108.0), medians/means within ~4%, tilting Zig. Residual tilt
  unresolved — could be unroll packing (Koru 2 CAS sites vs Zig 1),
  layout luck, or laptop spin noise.

## Ruled out by measurement (do not retry)

- `inline fn` on `__koru_handler_impl` — identical flag traffic.
- Deleting `_ = &x` discards — identical flag traffic.
- Flattening intermediate unions (keeping outer contract) — 17→15 flags,
  no wall-time change.
- Full hand-fused consumer — 4 flags, same wall time. The flags are a
  symptom worth deleting, not the perf driver in THIS benchmark.
- Stack-vs-heap ring placement WAS the ~25% earlier "deficit" — now
  normalized; both sides page-allocate.

## Emitter anatomy (the fix surface)

`src/visitor_emitter.zig` (5363 lines):

- `:2387` — `__koru_self_loop: switch (@as(enum { ... }))` — self-tail
  dispatch loop EXISTS.
- `:3028` — "dispatch loop — the mutual generalization of the
  self-tail-loop" — the generalization point.
- `:3430`–`:3469` — `is_self_loop` / `self_loop_canonical` detection,
  `while (true)` wrapper emission.
- `:1873` — "OPTIMIZED: Native loop from IR" path.
- `emitSelfTailReentry` — re-entry emission.
- `emitSubflowContinuations` (:3582, :3900 call sites) — where chain
  continuation dispatch is emitted.

**Key observation:** `output_emitted.zig` in this dir contains NO
`__koru_self_loop` — the consume chain (`consume_loop` → `dequeue` →
`check_if_done`, re-entered by the `#loop` driver `flow0`) does not take
the self-loop path. Two candidate root causes:

1. The chain is not self-recursive — it's a multi-tor cycle — so
   `is_self_loop` never fires. The `:3028` "mutual generalization" may be
   the intended home for this case and may not be complete.
2. Even where dispatch loops fire, the driver emits
   `var result_N = handler(...)` + memory-resident union + switch on the
   tag byte, instead of switching directly on the call result — an
   address-taken aggregate that survives SROA as a lone i8 alloca
   (`%.sroa.0...alloca i8` in LLVM IR).

Lars's hypothesis to check first: a loop jumping into a **single-branch**
target may already have (or deserve) a tag-free fast path — a one-variant
dispatch needs no tag at all, just the jump.

## Verification protocol (non-negotiable)

- Decisive check is `objdump -d` on the real test binaries — count flag
  ops in the consumer region. Target: 0–1, matching Zig.
- Rebuild via `./run_regression.sh 420_006_rings_vs_channels` — checksum
  must still print 49999995000000.
- Interleaved timing (K,Z,K,Z alternating, ≥30 pairs) is the honest
  estimator; block-ordered hyperfine means on a laptop are noise-grade.
- Wall-time improvement may be ~0 on this workload — that is a FINE
  result: the win is less emitted weight, verified at instruction level.
- Do NOT patch `output_emitted.zig` and call it a fix — artifact edits
  are diagnostics only ("patch the artifact, not a mock" measures the
  ceiling; the emitter change is the fix).

## Droplet note

`koru-benchmarks/scripts/bench-on-droplet.sh` runs the benchmarks suite
on a dedicated-vCPU DO droplet (x86_64 — separate board from M2). As of
2026-10-01 `doctl` auth is 401 — Lars must `doctl auth init`. This test
is NOT in that suite; either port it or `KEEP=1` and run binaries by hand.

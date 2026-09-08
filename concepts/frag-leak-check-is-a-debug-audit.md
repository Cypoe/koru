---
type: belief
id: frag-leak-check-is-a-debug-audit
provenance: trusted-jeans 2026-09-08 read Hello World's output_emitted.zig; leak counter was in every ReleaseFast binary including benchmarks
ts: 2026-09-08
tags: [koru, emitter, leak-check, release, benchmarks]
---

# The produced-program leak check is a Debug-mode audit (belief)

The leak counter and `koru_leak_check` are a Debug judge, not a shipping
invariant. ReleaseFast / ReleaseSafe / ReleaseSmall fold the increments and
the exit call at comptime (`builtin.mode == .Debug`). One emitted source
serves every optimize mode; a `zig build-exe -O ReleaseFast` of the file
is caught the same way `koruc build --release=fast` is.

The prior comment in the emitter said "Zero leaks is an absolute invariant
— no exemptions." That was the belief that put a global RMW in every
allocating ReleaseFast binary, including the benchmark suite. The pin is
`310_125`: same leaking program, Debug exits 1, ReleaseFast exits 0.

Throughput is aspirational. A json-parse before/after on a quiet machine
is the number that would justify "the audit was costing cycles." This
session's 520 → 325 MB/s run is withdrawn: local inference was likely
on the box, and a 40% drop is not what a comptime-folded counter can
do. `310_125` pins the gate, not the speed.

The sibling belief [[frag-produced-program-leak-check-is-allocator-opt-in]]
is about *which allocator* the counter watches. This one is about *which
build mode* runs the watch.

What would `correct` this: a ReleaseFast program that still increments
`__koru_leak_count`, or a Debug program that leaks and exits 0.

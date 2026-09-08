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

The gate is an integrity change, not a throughput story. A same-window
json-parse remasure (3s × 3, this machine, 2026-09-08) put ungated
`c0572ce5` at 589.8 / 590.9 / 581.6 MB/s (best 590.9) and gated
`6e3d6b41` at 595.2 / 604.1 / 606.7 (best 606.7). After's worst beat
before's best. The audit was not a hot-path cost at this scale.

The earlier 520 → 325 MB/s run stays withdrawn: the box was doing local
inference, and a 40% drop is not what a comptime-folded counter can do.
`310_125` pins the gate, not a speedup.

The sibling belief [[frag-produced-program-leak-check-is-allocator-opt-in]]
is about *which allocator* the counter watches. This one is about *which
build mode* runs the watch.

What would `correct` this: a ReleaseFast program that still increments
`__koru_leak_count`, a Debug program that leaks and exits 0, or a
quiet-window remasure where gated max sits below ungated min.

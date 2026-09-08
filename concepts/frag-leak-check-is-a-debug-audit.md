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

This is not a claim that ReleaseFast is faster. Measured this session on
json-parse (3s × 3, same machine, same protocol): before 520.0 MB/s best,
after 324.6 MB/s best. The after window followed a cold suite; the
integrity pin is the finding, not a throughput number.

The sibling belief [[frag-produced-program-leak-check-is-allocator-opt-in]]
is about *which allocator* the counter watches. This one is about *which
build mode* runs the watch.

What would `correct` this: a ReleaseFast program that still increments
`__koru_leak_count`, or a Debug program that leaks and exits 0.

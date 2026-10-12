---
type: belief
id: frag-a-trap-delivers-its-observable-stream-first
provenance: C-lane tagged-lifecycle tranche, 2026-10-12 — 690_116's stale-handle read fired `__koru_unreachable` correctly but lost `took 100` because abort() does not flush stdio buffers; the C binary's observable stream diverged from zig's while its crash was identical
ts: 2026-10-12
tags: [koru, c-lane, traps, stdio, observability, oracle]
---

# A trap must deliver its observable stream before it fires

`std/store`'s stale-handle floor is verified against an *observable*
contract: 690_116 expects `took 100` on stdout, then the stale-handle
message on stderr, then the trap. The C lane's first `__koru_unreachable`
did `fprintf(stderr)` + `abort()` — and `took 100` never appeared, because
the `fputs` sat in a stdio buffer `abort()` does not flush. The crash was
right; the program's output was wrong.

The belief: **an equivalence oracle compares streams, not crashes.** A trap
that preserves the diagnostic but loses the buffered output the program
already produced is a semantic divergence — the bytes are the contract,
and "it aborts either way" is comparing the wrong artifact. Zig flushes
because its panic path runs the panic handler's own output discipline; C
flushes because someone remembered `fflush(NULL)`. Every host port of a
trap path owes this audit once, and the audit is cheap exactly once: at
the sink, not at each call site (cousin to
`frag-trap-the-sink-not-the-emitter-sites` — the sink is also where the
ordering lives).

The general shape: a porting pass that copies the *mechanism* of a failure
("it prints and dies") without the *ordering* the runtime attached to it
("everything already produced is visible first") produces traps that look
green until a test with output-before-crash lands. EXPECT_TRAP tests are
the detector — a lane that skips them in its equivalence check (the C
harness does) has no oracle for this class at all.

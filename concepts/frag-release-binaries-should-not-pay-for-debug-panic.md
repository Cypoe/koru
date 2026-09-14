---
type: belief
id: frag-release-binaries-should-not-pay-for-debug-panic
provenance: asteroids binary-size dig (koru-libs games/asteroids, 2026-09-14) —
  a 235KB release binary against C's 34KB looked like a koru-runtime cost;
  symbol-level accounting showed 137KB was zig's self-hosted DWARF unwinder
  pulled by the default panic, and the game itself was ~22KB
ts: 2026-09-14
---

# Release binaries should not pay for the debug panic (belief)

Measured 2026-09-14 on `koru-libs/games/asteroids` (M2 Pro, zig 0.15.2):
a `--release=fast` user binary was 235,320 bytes, of which **137KB of
`__text` was `std.debug.SelfInfo` + `std.debug.Dwarf`** — the self-hosted
DWARF unwinder the default panic handler (`FullPanic(defaultPanic)`) links
to print a stack trace on panic. The game's actual code: ~22KB. The panic
machinery was ~6× the program.

`output_emitted.zig` now declares, for user output only:

    pub const panic = if (@import("builtin").mode == .Debug)
        std.debug.FullPanic(std.debug.defaultPanic)
    else
        std.debug.simple_panic;

Release asteroids is 74,408 bytes. Debug is unchanged — full traces where
they matter, a message + trap where they don't.

The belief: **the emit decides what the runtime costs, and the host's
defaults are not free.** Zig's default panic is correct for a toolchain
debugging itself; it is not correct for a shipped program. Any host-service
default we inherit silently — panic handlers, unwind tables, allocator
policy — is a size/behavior tax the user never opted into. The audit
question is always "what did the emit pull that the program never called?"

Same shape as the allocator spine (DebugAllocator measured catastrophic for
throughput, c_allocator spine chosen instead): the host default serves the
host's use case, not ours. Optimized builds have no debug info for the
unwinder to read anyway — the machinery was dead weight twice over.

Open: `simple_panic` writes the bare message, not `panic: <msg>` — if any
consumer asserts on that prefix in an optimized build, the pin will say so.

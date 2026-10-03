---
type: belief
id: frag-an-emitted-memset-is-not-the-platforms-memset
provenance: prime-sieve Koru-vs-Rust revisit, 2026-10-03 — an x86 gap first
  narrated as microarchitecture closed when field zeroing moved off `@memset`
ts: 2026-10-03
---

# An emitted `@memset` is not the platform's memset (belief)

A Koru program built with `-lc` still does not call libc's `memset` or
`memcpy`. Zig lowers `@memset`/`@memcpy` to its own compiler_rt copies,
linked into the binary as local symbols (`nm`: `t memset`, `t memcpy`), and
those shadow glibc's. A Rust binary on the same box imports
`memset@GLIBC`. Our binary looks like a libc program, but its bulk-memory
primitives are a plain SSE loop that glibc's tuned `rep stosb`/AVX paths
outperform.

On the prime sieve this cost 6% end to end on Xeon 8168/8280 (36.8k vs
39.1k passes/5s), against a memset that profiles at only ~1% of cycles. Most
of the loss shows up *downstream*, in the dense marker sweeps that run right
after the zeroing. So the cost does not show up where the call does. Rust
was not winning on code: its marker loops are instruction-identical to ours,
and with glibc zeroing, Koru lands within 0.1–1% of it on three droplets.

The ruling: when a hot path's runtime cost depends on a bulk-memory
primitive, the emitted symbol table is part of the evidence. Before blaming
silicon, check which `memset` the binary actually calls. "The silicon did
it" was asserted here twice before anyone looked. A gap that changes sign
between two chips with the *same core* (8168 vs 8280) cannot be a core
effect.

Open: the field constructor now zeroes through libc, which is a local fix.
Every other emitted `@memset`/`@memcpy` (store, rings, buffers) still goes
through compiler_rt. Whether the toolchain should route them to libc when
linked is a build-wiring decision, not yet made.

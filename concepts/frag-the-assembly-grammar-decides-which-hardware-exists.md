---
type: belief
id: frag-the-assembly-grammar-decides-which-hardware-exists
provenance: 2026-10-12 — closing the last zlib-vs-owned-encoder deficit (the CRC trailer). The crc32x asm arm was declared unreachable because Zig's `r` constraint binds GPR64; the pmull path was assumed equally blocked until a probe compiled `pmull %0.1q, %1.1d, %2.1d` under the `w` constraint and it ran.
ts: 2026-10-12
---

A hardware instruction that Zig's inline-asm grammar cannot spell is not a
missing hardware path — it is a missing *spelling*, and the two must never
share a verdict.

The failure this corrects: `crc32x` needs w-register operands (32-bit GPRs)
and Zig 0.15.2's `r` constraint only binds x-registers — no width modifier,
so the instruction was declared unreachable and removed. That verdict was
correct *for that instruction class*. What it silently generalized was
"hardware CRC is out of reach" — while `pmull`/`pmull2`, which bind SIMD
registers, sat one `w` constraint away, unprobed. One probe
(`pmull v0.1q, v1.1d, v2.1d`, `"w"`) compiled and ran; the full Gopal/Ozturk
fold then landed bitwise-verified against the table path across ~2700 sizes,
taking the trailer from 0.44µs/KB to ~0.03µs/KB and flipping the last
benchmark band where zlib still won.

The rule: when an asm spelling fails, name the register class that failed
and check what other classes the remaining constraints bind — before
writing "the hardware path is unbuilt" into a concept. A dead arm in one
constraint class says nothing about another, and a frag that records the
wider verdict teaches the next session to stop early.

## Related

- orisha:frag-the-trailer-cost-more-than-the-codec — the sibling frag this
  correction feeds; the trailer's second correction is this belief applied.

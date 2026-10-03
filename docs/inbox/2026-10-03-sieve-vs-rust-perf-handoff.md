# Resolved: prime-sieve Koru-vs-Rust — Koru +19% on x86

Date: 2026-10-03 · Fixes: `78ef909c2` (libc zeroing), `2700a4366` (sweep
direction) · Beliefs: `frag-an-emitted-memset-is-not-the-platforms-memset`,
`frag-a-sweep-should-start-where-the-last-one-left-the-cache`

## Final result

Interleaved n=6 per droplet, single-threaded, all binaries validate 78498:

| box | koru | rust | lead | rounds |
|---|---|---|---|---|
| Xeon 8168 #1 | 46,697 | 39,152 | +19.3% | 6/6 |
| Xeon 8280 | 52,039 | 43,856 | +18.7% | 6/6 |
| Xeon 8168 #2 | 46,850 | 39,330 | +19.1% | 6/6 |
| ARM (local) | ~86.8k | 77.6k | ~+12% | unchanged |

## Cause 1 — zeroing went through compiler_rt, not glibc

`std/field:new-heap` zeroed the buffer with `@memset`. Zig lowers that to the
binary's own compiler_rt `memset` (a local symbol, `t memset` in `nm`), which
shadows glibc's. Rust's binary imports `memset@GLIBC`. `78ef909c2` routes
zeroing through libc (`bzero` when `link_libc`). That took x86 from ~6.5%
behind to within 0.1–1% of Rust — near-parity, not a win.

## Cause 2 — every sweep ran the same direction

The sieve makes ~170 full passes over one 62.5 KB field per run. Every marker
swept forward: each pass ended with the field's tail in L1 and started at the
head, which a 32 KB L1D had already evicted. `2700a4366` gives every generated
marker a direction; `Field` alternates direction per mark when the field
exceeds the runtime-queried L1D (sysconf on glibc, sysctl on Darwin; off when
unknown, and off on the ARM laptop whose 64 KB L1D fits the field). The marker
loops are instruction-identical to Rust's — the win is sequencing, not codegen.
This took Koru from ~parity to +19%, winning all 18 interleaved rounds.

## Prior measurements (memset fix only, n=6 per box)

| box | before | memset fix | rust |
|---|---|---|---|
| Xeon 8280 #1 | 37,555 | 39,768 | 40,156 |
| Xeon 8280 #2 | 36,998 | 39,372 | 39,470 |
| Xeon 8168 | 36,769 | 39,077 | 39,130 |
| ARM (local) | ~86.4k | 86.2–86.9k | 77.6k |

## What the previous version of this file got wrong

- **"27% on Cascade Lake"**: one droplet's result. Two fresh 8280s gave 6.5%.
- **"MLP / fill-buffer deficit in the sparse marker"**: false. On the 8168,
  L1 load misses per pass are equal (81.6k vs 80.8k), sparse cycles per pass
  are equal (265k vs 263k), and the fill-buffer-full cycles are equal. The
  earlier "30% more L1 misses" compared Rust's 10 s perf window against
  Koru's 5 s window.
- **"Hardware-dated claim"**: the 8168 and 8280 share a core design, and the
  gap was the same on both. The cause was in the binary, not the silicon.
- The rejected levers (`DENSE_LIMIT=512`, sparse prefetch) stay rejected.

## Ruled out with measurements

Field alignment (offsets 0/8/16/32/48/2048 within a page: flat), front end
and the JCC erratum (Koru has *fewer* MITE µops than Rust), syscalls and page
faults (identical), marker codegen (dense `__mm_23_12_31` is
instruction-identical to `extreme_reset_031`; the sparse loop is 12 vs 19
instructions with the same indexed `orb` forms).

## Open

- Ice Lake 8358 — the published claim's own silicon — is still unmeasured; no
  c-2 draw landed it. The +19% is proven on Skylake-SP and Cascade Lake only.
- The direction trick is ~20 lines and portable; Rust could adopt it and the
  gap would narrow. The durable lead is that ours lives in the stdlib
  transform, not in application code.
- Descending sweeps cost 6–9% on ARM when active — measured, not explained.
  Alternation correctly stays off there, but the cost itself is unexplored.
- Every other emitted `@memset`/`@memcpy` (store, rings, buffers) still goes
  through compiler_rt. Routing them to libc when linked is a stage-D
  build-wiring decision for Lars.
- The cost lands downstream: memset profiles at ~1% of cycles, but the dense
  sweeps that follow get slower. The exact mechanism (line state left by
  `rep stosb` vs SSE stores) is inferred, not measured.

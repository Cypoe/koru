---
type: belief
id: frag-a-sweep-should-start-where-the-last-one-left-the-cache
provenance: prime-sieve Koru-vs-Rust revisit, 2026-10-03 — alternating
  std/field marker direction took x86 from behind Rust to +19%
ts: 2026-10-03
---

# A sweep should start where the last one left the cache (belief)

The sieve makes about 170 full passes over one 62.5 KB field per run, one per
prime. Every marker swept forward, so each pass ended with the field's tail
resident in L1 and the next pass started at the head, which had been evicted.
On a 32 KB L1D, every line of every sweep came from L2. Rust's solution does
the same, which is why the two ran neck and neck. Same algorithm, same
traffic.

Alternating direction stops throwing that residency away. Forward, then
backward, then forward: each sweep begins on the half of the field the
previous one just left in L1. On Xeon 8168/8280 this took Koru from behind
Rust (39.1k vs 39.2k passes/5s) to +19% (46.7–46.9k vs 39.2–39.3k; 52.0k vs
43.9k), ahead in 18 of 18 interleaved rounds on three droplets.

It is not free when the field already fits in L1. On Apple M (64 KB L1D
reported, field 62.5 KB) descending sweeps cost 6–9% and buy nothing. So
alternation is conditional: on when the field exceeds the runtime-queried L1D
(sysconf on glibc, sysctl on Darwin), off when the size is unknown. The
condition is measured from the machine, not hardcoded.

The general rule: when a kernel makes repeated passes over a working set
larger than a cache level, the order of those passes is part of the
algorithm's cost, even if every individual pass is optimal. The marker loops
were instruction-identical to Rust's; the win was in sequencing, not in code.

Open: Ice Lake (48 KB L1D) is unmeasured. The 6–9% ARM cost of descending
sweeps is measured but not explained.

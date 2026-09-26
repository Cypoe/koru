# 007 — primitive price list

The scenario board (`003_ecs_reactive`) conflates init, sweep, resolve, write,
and dispatch into one number per scenario. This benchmark isolates the emitted
primitives: one op per arm, a bare-array `zig_flat` twin doing the equivalent
work, interleaved medians, sinks bit-checked across the ports.

Where `003` says "koru is 1.3x slower on fanout", this suite says *which op
carries it*.

## Run

    ./run.sh            # REPS=7 interleaved, writes results.jsonl

## The table

n = 100k entities × 100 frames for sweep arms (per-op = elapsed / 10M);
`insert*`/`drain` are single-shot lifecycle arms (per-op = elapsed / 100k).
Medians of 7 interleaved reps, both binaries ReleaseFast.

| arm | koru spelling | zig twin | zig | koru | ratio | attributed cause |
|---|---|---|---:|---:|---:|---|
| `read_row` | `! query e \|> stored{acc.sink += e.hp}` | `sink += hp[i]` | 458µs | 456µs | 0.99x | sweep + write-through — at parity; the event machinery is free when LLVM sees the whole loop |
| `capture_for` | `capture{s} … captured{s: c.s + scratch[i].v}` | `s += gi[i]` (frame-local) | 914µs | 910µs | 1.00x | register fold — capture emits a real register cell |
| `read_handle` | `bodies[bxref[i].h].hp` read | `hp[gi[i]]` | 2170µs | 9517µs | **4.39x** | handle resolve ≈ **0.73ns/op** over a bare index (decode + brand/range check, even under `gen0`) |
| `write_row` | `stored{e.hp: e.hp - 1}` in sweep | `hp[i] -= 1` | 700µs | 966µs | 1.38x | write event ≈ +0.03ns/row — mostly vectorization shape |
| `write_handle` | `stored{bodies[bxref[i].h].hp: …-1}` | `hp[gi[i]] -= 1` | 3348µs | 10653µs | **3.18x** | resolve on both sides of the write ≈ **0.73ns/op** |
| `write_sink` | `stored{acc.sink += scratch[i].v}` | `sink += gi[i]` | 939µs | 914µs | 0.97x | singleton write-through — LLVM promotes the cell |
| `event_call` | `ping(v: scratch[i].v)` → one write | `ping(gi[i])` | 911µs | 919µs | 1.01x | tor call — free; arg-promoted and inlined |
| `insert` | counted-for fill, unindexed store | array fill | 60µs | 65µs | 1.08x | column stores + mint — near parity |
| `insert_idx` | counted-for fill, indexed store | same array fill | 58µs | 417µs | **7.19x** | index join ≈ **3.6ns/row** — see frontier note below |
| `drain` | `rule(bodies) ! row e \|> take` | swap-remove sweep | 32µs | 104µs | **3.2x** | gen-bump reset; residual is one-time `hslot_gen` page faults — see drain note below |
| `routed` | `! query e when e.act == 1` (indexed) | `for(active)` | 465µs | 578µs | 1.24x | bucket walk + resolve ≈ 1.1ns/member residual |
| `guarded` | `! query e when e.on == 1` (unindexed) | `if(on[i]==1)` | 2695µs | 2683µs | 1.00x | sweep + guard — parity |
| `watch` | write a watched column per row | write + counter | 1381µs | 1382µs | 1.00x | announce — free at this arity |
| `grid` | `scratch[i].v += 1` | `gi[i] += 1` | 1389µs | 1377µs | 0.99x | grid RMW — parity |

## What the prices say

**The two expensive primitives:** index join (~3.6ns/row) and handle resolve
(~0.73ns/op, paid twice on `write_handle`). Drain left the list — see the
note below. Everything else — sweep, capture fold, singleton write-through,
event call, watch announce, grid — is at or under parity in the
straight-line case.

**The machinery is free when LLVM can see it.** `write_sink` writes a store
cell through the full `stored` event path at *parity* — a singleton column
promotes to a register in a visible loop. The ~3ms write-through tax measured
on `003`'s fanout was not the write primitive; it was writes behind a call
boundary inside an observer dispatch, where promotion can't reach. Per-op
price ≈ 0; *placement* price is where the money goes.

**Resolve is the workhorse cost.** `read_handle`/`write_handle`/`routed` all
pay ~0.7–1.1ns per handle→row. Under `__koru_gen0` the resolve is already
just shift/mask/range — the residual is decode + checks vs a bare index.
That is the handle tax, and it multiplies wherever a port respells an
indexed expression (003's fanout pays it ~3x per event).

**`insert_idx` is now the widest ratio** (7.19x) — index maintenance the
bare-array baseline never pays, and part of it is semantic surplus: the
index joins `bucket[0]` for keys the workload never queries.

**`drain` repriced (measured 2026-09-26):** the sweep now emits the `clear`
unit's canonical reset — one gen bump over `0..hslot_next`, then `len`,
`free_len`, `hslot_next` drop to zero and `ident` re-arms — instead of
materializing take's freelist order per row. The old shape's measured cost
was mostly *cold demand-zero page faults* on `hslot_free`/`hslot_gen` (~1.2MB
of bookkeeping arrays the deferred fill never touched), not loop cost: a
verbatim replica of the old emitted loop ran 0.19ns/row warm. The new shape
pays only the `gen` fault pass, and re-arming `ident` means drain *stays*
fast — the old shape flipped `ident` false forever, so every
drain-after-refill took the scalar slot-mapping path (~2.2ns/row measured).
Warm steady-state drain is ~0.1ns/row (≈10µs at 100k). A `gen0`-gated
`@memset` halved the cold fault pass (store-only, ~50µs) but its extra
branch perturbed codegen layout enough to cost unrelated arms ~40% — the
unconditional bump is the robust shape. The one observable change: refill
issues slots in fresh order rather than take's LIFO pop order — same slot
set, different handle bit values.

**`insert_idx` frontier (measured 2026-09-25):** the bulk join now keeps the
join key, the previous key, and the bucket tail (`len`/`ptr`/`capacity`) in
registers, commits `items.len` on a key switch and at loop end, and mints
the handle from the register slot instead of re-reading `row_hslot` — three
store→load forwarding chains removed. A hand-written Zig replica of both the
old and new emitted loops measures **3.07 vs 2.94 ns/row** — the emitted
code is at parity for this data structure. The residual is the join design
itself (`AutoHashMapUnmanaged(i32, ArrayListUnmanaged(i64))` + per-row
handle pack), not codegen waste: beating it wants a different index
representation (dense bucket arrays, key-domain specialization, or rows
instead of handles when `__koru_ident`), not another emission tweak.

**Missing arm, by design:** `captured` inside `! query` does not lower —
query bodies are transplanted into generated per-row functions where the
caller-scope capture cell isn't visible (`KORU040 unknown tor
'main:captured'`). That is why `read_row` can only be spelled with
write-through; the sweep-read arm is the pinned gap itself.

## Methodology notes

- Accumulator arms must read memory (`scratch[i].v`). A pure function of `i`
  is closed-formable — `s += i` over a fixed range measured 42ns for 10M ops
  because LLVM replaced the loop with its sum. A serial recurrence
  (`s*31+i mod p`) resists folding but its ~5ns dependency latency hides the
  machinery under test. Memory loads are neither.
- `--release=fast` is enforced in `run.sh` — the koruc invocation must report
  ReleaseFast or the run refuses.
- `zig_flat` is compiled `-O ReleaseFast`; sinks are asserted equal across
  impls in the report script, not eyeballed.

## Driving challenges

The price list ranks; a challenge is what makes the current worst entry bend
in a realistic program. Loop: price → challenge (protagonist = the worst
primitive) → fix or frontier → reprice. Current protagonists, in order:
`insert_idx`'s join (at the representation frontier), `read_handle`'s
resolve.

---
type: belief
id: frag-flat-continuation-segments-beat-the-native-stack
provenance: Bend 2 codegen dissection + hand-rolled prototype spike, 2026-09-18; implemented and protocol-measured same day
ts: 2026-09-18
---

# Flat continuation segments beat the native stack on chained scalar recursion

For scalar recursion whose non-tail self-calls **chain** — a call's result
feeds the next self-call, ending in a tail self-forward — emitting **flat
continuation segments** beats the native call stack by a 1.2–6.5× class
margin, measured under the suite's own oracle-gated protocol: ackermann
147.2 → 22.7 ms (6.5×, beats Bend's 64.0 and C's 130.0 on the same board),
hanoi 74.8 → 53.1, tak 44.0 → 37.2. Combining recursion (fib's `a + b`)
*loses* the same way (~20% slower when flattened — the fid dispatch loses to
the hardware return-address-stack predictor), so the emitter now carries
**two calling conventions and selects per-handler by proof of shape**.

**The mechanism:** uniform-signature segment functions —
`fn(sp: [*]u64, r0..rN) u64` — dispatch through `@call(.always_tail)` over an
explicit continuation stack of uniform-width lanes `[fid][live…]`. A segment
call is a `jmp` with args already in registers: no frame setup, no
callee-saves, no return-address traffic; a lane is written once, read once,
reused in place. The native stack pays a full ABI frame per call (~8 memory
ops, disassembly-verified: tak spills eight registers) for bookkeeping the
compiler already knows statically. The lane stack is lazily `mmap`'d with a
`PROT_NONE` guard page — overflow faults exactly like a native stack
overflow, zero hot-path cost; Debug builds keep a `@panic` diagnostic.

**The selection rule** (the part Bend can't do — it pays its segment
machinery on every call): flat emission fires only when a non-tail
self-call's continuation suffix re-enters the same event — chained
recursion over scalar machine-word args, single return, no effects. That is
ackermann/hanoi/tak. Fib's continuation combines rather than chains, so it
stays native and keeps the 28 ms row. Of 19 koru kernels on the Osprey
board, exactly those three qualify — verified by compiling all of them.

**Auto-selected, not a spelling.** No `|flat` exists for the same reason no
`|reentry` exists: when the emitter can prove a shape is faster and
semantics-identical it emits it. Pins: `320_148` (chained → seg symbols +
oracle) and `320_149` (combining → zero seg symbols) hold the boundary in
both directions.

**Honest costs:** lane chains don't produce native backtraces
(`__koru_seg_k2 → br x4`, not frames); self-calls only (mutual groups are
mechanically possible but out of gate scope); scalar args bounded by the
register file; the shared lane stack is per-module state, single-threaded
by assumption.

**Direction it opens:** the lane stack is also the fork point — a call site
can emit "push lane" *or* "alloc task node", which is how Bend gets
fork/join (`bend-par` tak 52.8). The substrate now exists; whether a
`seq`/task path over it is wanted is a separate measurement. It also
removes the stack-depth ceiling outright — lanes are heap memory.

**What would correct this:** flat measuring at or below native parity on a
chained kernel; LLVM recovering the same shape from structured recursion;
a real workload where the gate selects wrongly and native would have won.

---
type: belief
id: frag-proc-body-internals-are-site-hygienic
provenance: 2026-09-14 — koru-libs/asteroids-net: clock:ticks' `var __i` shadowed
  udp:packets' `var __i` when nested inlined (third collision in one session:
  raylib `i` × udp `i`, std/io print's `__f` param × raylib `__f`, then
  clock `__i` × udp `__i`)
ts: 2026-09-14
---

# Proc-body `__` internals are per-site hygienic — the emitter keeps the convention mechanically

An effectful `~proc|zig` body inlines into the caller's frame, opaque text and
all. Everything *named across* that boundary already got site-unique spellings —
event params (`__koru_arg_`), consumer branch bindings (`__koru_bind_`), result
temps (`result_e{d}_`), the proc label itself (`__koru_proc_{N}`). The one
surface nobody renamed was the body's **own internals**: `var __i`, `__f`,
`__p`, `__cap` — the author's "don't touch" namespace.

Two libraries independently writing `var __i` is not a naming mistake; it is
the inevitable consequence of a convention the emitter did not keep. Zig
forbids shadowing at function scope, so any nested composition of two such
procs was a compile error neither side could see coming.

The rule: in `rewriteEffectfulProcBody`, every `__x` token becomes
`__x_s{N}` where N is the splice's `proc_uniq`. `__` is a safe namespace to
rename uniformly because Koru bindings can't spell it and `.`-access is
boundary-excluded. `__koru_*` is excluded — that is the emitter's own
namespace, and generated code must stay resolvable.

What this does NOT cover, deliberately:

- **Non-`__` producer locals** (`var i` in a proc body) still collide with
  each other. The consumer-binding rename (400_169's mechanism) covers
  consumer-vs-producer; producer-vs-producer on plain names remains a
  convention violation — `__` is the contract.
- **The JS emitter** (`emitProcBodyWithSplicedEffectCalls`) has the same
  class of hole and no equivalent pass yet.

---
type: belief
id: frag-signal-lift-vs-native-port
provenance: session 2026-09-14 — ruled in conversation: koru/signal is the lifted engine, std/signal the native reimagining
ts: 2026-09-14
tags: [koru, signal, kernel, lift, eel2]
---

# koru/signal is a lift; std/signal is a native reimagining that lowers to kernel — and the oracle inverts at the port (belief)

`koru/signal` is a **lifted foreign engine**: Cockos EEL2 (permissive WDL)
plus the Intranquil JSFX→Zig transpiler plus the 6digit-world WMFX fork —
the wrap-don't-reinvent doctrine applied to our own engine. It is "a little
foreign" the way `libs/raylib` smells like C: the smell is honesty about
what is underneath. It gets first-class treatment as a lift — full surface,
parity pins, real callers — indefinitely. There is no graduation pressure.

`std/signal` is a different thing: a **native reimagining** where a model
lowers to ordinary Koru machinery — state schema as `std/proto`, ports as
phantom-labeled scalars, tick bodies in kernel vocabulary over store rows,
units as a closed-vocabulary layer (see
[[frag-dimension-algebra-is-model-scoped]]). The emit path evaporates: no VM,
no `models/*.zig` weld, no foreign runtime. "Runnable as part of
`std/kernel`" is literal — a per-entity detector tick over carried-state
columns *is* `kernel:self`.

The oracle direction **inverts at the port**. Today WMFX oracles
koru/signal (`breath_parity`: koru-authored ≡ reference emit). Once the
native path exists, koru/signal oracles *it*: same model, both engines,
parity-pinned — a native reimagining checked against its own lifted
ancestor. Every WMFX corpus model ported into koru/signal now is a test
case in that future suite for free.

The design rule this hands the lift's surface work: **every koru/signal
feature must answer "could this lower to kernel + proto + phantom?"** If
yes, it is on the native trajectory. If it needs EEL-specific machinery, it
is a lift-only capability and gets marked as such — the same way raylib's
transliterated calls get marked as lift-smells. We design the native surface
*on* the foreign engine; the engine is the oracle, the surface is the
product.

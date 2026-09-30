---
type: belief
id: frag-the-fused-observer-layer
provenance: 2026-09-30 tap-vs-watch equivalence measurement (/tmp/fusion):
  both spelled a 10M accumulate observer; identical emitted static-call
  shape, identical 4.3ms user time
ts: 2026-09-30
---

# The fused observer is one mechanism, and the ring is its remainder (belief)

A tap and an effect-branch watch are not two observer features with different
speeds — they are the same mechanism at one layer: compile-time fusion of the
listener into the producer's continuation tree. `std/taps` splices the
observer's branch body into the produce site's continuation (AST surgery,
`wrapContinuation`); `std/store`'s `! field` watch transplants its body into
the store's write-path handler. Emitted, both are a chain of static
`.handler()` calls with no registry and no dispatch — and measured on the same
10M-message accumulate loop they cost identical user time (4.3ms). The core
language does not lose to the library trick; the trick was never a separate
technique, only an earlier spelling of it.

The layer's boundary is fusion validity, not a flag or an annotation: a
listener that shares the producer's stack can be spliced; one that cannot —
a different thread, a competing consumer, a deferred obligation — needs
transport, and transport is what the ring is. So the ordering runs the other
way from intuition: the fused observer is not a cheap substitute for a
channel, and the channel is not a heavy way to get a callback. They sit at
different layers because they answer different questions, and the grammar
routes to the right one without being asked — `!` on a store fuses, `!` on a
channel transports.

## What follows

- **Neither belongs in a transport benchmark.** A fused observer has no
  transport to time; its row in a channel suite measures a deleted workload.
  Exclusion is not omission — the layer is real, it is just invisible to the
  instrument (420_006 comment now records this).
- **A tap-outruns-`!` result would be a compiler defect, not a workload
  difference.** Where fusion is valid the emitted shapes converge; any gap
  between them is lowering weight around the same work, and it has a floor
  of zero.
- **The cross-language claim is about the layer, not the numbers.** Go's
  channel is always transport — there is no fused-observer layer to compare
  against. "Koru tap vs Go channel" benchmarks a layer Go does not have
  against one it does.
- **Where fusion is impossible, transport is the semantics — not overhead.**
  The ~12x the channel path pays over the fused loop is the ring plus
  scheduling, the honest price of decoupling. Optimizing it means shrinking
  the transport, not chasing the fused number.

## Open

Whether a `!` arm ever wants a *declared* fused mode — a channel-shaped
surface whose consumer is provably same-stack and could splice instead of
schedule. Today's answer is that `|>`/`=>`/supervision already spell that
shape; if a program ever reaches for `!` wanting fusion and gets transport,
that is the gap this fragment says to look for.

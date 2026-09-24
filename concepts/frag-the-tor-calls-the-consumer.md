---
type: belief
id: frag-the-tor-calls-the-consumer
provenance: channel design session 2026-09-24 — Lars correcting a repeated
  mis-model; CHANNEL.md rewritten on this correction
ts: 2026-09-24
---

# The tor calls the consuming code — the arrow is inverted

The persistent mis-model: a flow that fires `! recv` on an empty channel
"suspends mid-statement until a value arrives," which then needs a
deferred-resume mechanism, a `Resume<T>` handle, a `pending` result, a
`[deferred]` marker. All of those are imports from languages that pass
computations around as *values* — promises, iterators, continuations —
and they are the wrong shape for Koru.

The actual model (Lars, 2026-09-24):

- **The ownership arrow is inverted.** In mainstream languages the
  consumer holds the producer — the loop owns the iterator, the caller
  owns the promise — and drives it. In Koru the tor holds the consuming
  code and *calls* it. An effect fire invokes the handler bound at the
  call site (emitted: `__H.ask(q)`); a `|>` continuation is code the
  result gets delivered *into*. The consumer is called; it never drives.
- **Effect branches are uncolored.** There is no sync/async marker on an
  effect arm — the *caller* takes the color by which surface it invokes
  and how the composition is arranged. "Deferred" is not a property a
  call can have; it is a property of who steps the unit. Handlers can
  return continuations — control flows both directions through the same
  junction.
- **There is no "mid-flow."** A `|>` chain is not a call stack you stand
  inside; each step is a firing whose continuation is already structure.
  Vocabulary like "suspend inside a statement" names a place that does
  not exist.
- **A generator is a firing pattern, not an object.** A tor pulses — the
  tor can natively produce what other languages reify as lazy iterators,
  with no iterator value and no suspended frame. The tor's implementation
  must be correct under wildly parallel firing; that burden is native and
  lands on the impl, not on an annotation.

Consequence for surface design: nothing about a channel (or a "blocking"
anything) needs the language to gain a suspend/resume primitive. A `!`
arm consumer is already deferred execution — the channel calls the
consumer's code when a value lands. Rendezvous/cap-0 is a *surface*
question — a send whose ok-continuation fires on the consumer's take —
not a compiler gap.

The diagnostic for this mis-model: any sentence that asks "where does the
continuation object live?" In Koru the answer is always the same — it
isn't an object; it's structure the tor was given and calls.

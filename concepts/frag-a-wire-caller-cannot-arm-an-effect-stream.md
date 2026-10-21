---
type: belief
id: frag-a-wire-caller-cannot-arm-an-effect-stream
provenance: std/fs collect-lines work 2026-10-20 — 440_041's wire could not
  consume read-lines-in's `! line` pulses; collection became the only
  wire-visible path, and FieldValue grew string_array to carry it
ts: 2026-10-20
tags: [koru, wire, effects, bridge, agent-channel]
---

# A wire caller cannot arm an effect stream — collection is load-bearing (belief)

Koru's `! branch` arms are how a caller consumes a pulsed stream: read-lines
emits `! line` per row and a compiled caller folds them live. The wire has no
spelling for that. A wire item arms terminal outcomes only, so every
`!`-pulsing verb is invisible to the surface the agent actually speaks —
`read-lines-in(d, path)` dispatches fine and reports its `| done`, and the
lines never existed as far as the model can tell.

Two responses present themselves and only one is honest. Wrapping the verb in
a joined-string return is `read` with extra steps — the stream shape dies in
the join. The real answer is a materializer on the capability:
`collect-lines` runs the pulse loop host-side and returns the stream as a
`[]string` field. That is why FieldValue widened from scalar-only to
`string_array` — the wire's value vocabulary grew its first composite to
carry it, and `"value":["hello.txt","invented.txt"]` is structure the model
indexes, not text it re-parses.

The ruling shape: **an effect stream a wire caller must consume becomes a
collected array.** `capture` was rejected as the name — Koru already
overloads it (capture syntax, `! as` cells) — `collect-lines` names the fold.
Whether wire arms ever spell `!` branches (the effect-as-data direction,
streams riding a socket) is an open question this does not answer; today the
materializer is the only path, and a verb that only pulses is a verb the wire
cannot see.

Pins: 650_010 (collect-lines consumed Koru-side, `xs.len`/`xs[i]`), 440_041
(`{"branch":"lines","value":["the agent wrote a verb"]}` on the wire).

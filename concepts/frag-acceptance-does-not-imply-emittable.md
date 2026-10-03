---
type: belief
id: frag-acceptance-does-not-imply-emittable
provenance: obligation fuzz sweep 2026-10-03 — arm-end-consume mutants over the 330_07x family (probe_arm_end_consume_emit.kz)
ts: 2026-10-03
tags: [koru, emission, coordination, layered-acceptance, fuzzing]
---

# A program can pass every semantic wall and still be unemittable — the accepted set is larger than the set the backend can lower (belief)

The tacit model is a chain: frontend accepts shape, coordination accepts
semantics, emission lowers what was accepted. Each layer is assumed *total* over
the one before it — whatever coordination says yes to, the emitter can render.
Measured false: a fold outcome arm routed to a discharger (`| again v |>
done(h: v)` — the back-edge consumed, never re-entered) passes `-c` and all
twenty coordination passes, then emits `loop: while (true)` with no
`continue :loop` and a `var` that is never mutated. Zig rejects the artifact.

Two independent partialities hid inside the "total" assumption:

- **The checker tracks the obligation, not the declared outcome.** Routing the
  same arm to a non-consumer refuses correctly (KORU022 — obligation dropped).
  Routing it to a discharger satisfies the obligation state and sails through —
  while `spin`'s declared `-> *Handle<owned!>` is never produced on that path.
  The drop is checked; the unproduced return is not.
- **Emission keys structure on the arm, not on the edge.** The `loop:` label is
  emitted because a back-edge-shaped arm exists; whether a `continue` is
  emitted depends on the arm's routing. The two facts are not tied, so an
  accepted program can produce a label nothing jumps to.

The fuzzing consequence generalizes: the verdict matrix must have a real
backend column. `-c`-green tells you about the shape layer; coordination-green
tells you about the semantic layer; neither certifies the emitted artifact —
`frag-a-compile-only-test-cannot-see-the-artifact` is the same blindness one
level down, in the *test markers*. Here it is in the *compiler*: acceptance is
not emittability, and "all passes green" is not "compilable output."

Open: is the arm-without-return program semantically legal (flow ends early,
spin's return simply unreachable) with an emission bug — or illegal, with a
checker gap where KORU022 should also watch the declared return? Lars's call;
the repro pins the current acceptance either way.

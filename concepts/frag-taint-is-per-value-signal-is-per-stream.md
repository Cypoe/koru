---
type: belief
id: frag-taint-is-per-value-signal-is-per-stream
provenance: session 2026-09-14 — the anti-cheat division that fell out of mapping phantom obligations and signal models onto a game server
ts: 2026-09-14
tags: [koru, phantom, taint, signal, security]
---

# Taint is per-value, signal is per-stream — two detection organs with disjoint expressiveness (belief)

Phantom obligations and signal models look like competitors for
"detection." They are not — they express different things entirely, and
conflating them hides what each is for.

- **Phantom taint is per-value, compile-time, zero-cost.** An obligation on
  a scalar answers "was *this value* through the sanitizer" — provenance.
  `[]const u8<net:tainted!>` produced by a socket cannot reach a sim sink
  that requires `<!tainted>` discharged; the wire boundary *is* a taint
  boundary. It sees one value at a time and is blind to sequences.
- **Signal models are per-stream, runtime, statistical.** A model answers
  "does this *sequence* look human" — velocity sustained above the possible,
  action rate over budget, aim-distribution drift. It sees a behavior over
  ticks and is blind to provenance.

Anti-cheat needs both halves and each organ owns exactly one: distrust the
client's *values* (phantom — cannot compile into the sim unvalidated) and
distrust the client's *behavior* (signal — physics-consistency and rate
detectors over the tick stream). Neither substitutes: taint cannot see
time, detectors cannot see provenance.

The same division runs the honest half of the story too: server telemetry
(tick_ms, bytes/snapshot) is per-stream detection pointed at ourselves —
the same signal organ, different telemetry. The instrument that watches the
players and the instrument that watches the server are one machine.

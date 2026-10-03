---
type: belief
id: frag-a-cause-guessing-message-must-surface-the-evidence-it-ignored
provenance: obligation fuzz sweep 2026-10-03 — koruc reported "zig build-exe killed by signal 6 — probably OOM" for a clean zig error exit; the panic trace that would have disambiguated was captured in result.stderr and dropped
ts: 2026-10-03
tags: [koru, diagnostics, subprocess, reporting]
---

# A diagnostic that guesses a cause while discarding the evidence is worse than silence — the guess calcifies into a wrong memory (belief)

The generated backend driver spawns `zig build-exe` and branches on the child
term. The `.Exited` branch forwarded captured stderr; the `.Signal` branch
printed "usually means the machine ran out of memory" and dropped
`result.stderr` unread. A zig *panic* also dies by signal (SIGABRT) and leaves
its entire trace on stderr — the one place that could distinguish "OS killed
it" from "the child crashed." The report had the evidence in hand and threw it
away, then guessed.

The operational cost measured: signal 6 during a concurrent-cache run was
read as OOM — a machine fact — when it was a cache-contention abort, a
*scheduling* fact. The fix is not a better guess; it is emitting the trace
first and the guess second. Any failure report that names a cause must first
show everything the dying process said: the guess is a hypothesis ranked
*after* the evidence, never instead of it.

Cousin of [[frag-a-failure-that-looks-like-success-is-unfalsifiable]]: that one
is observations that cannot differ; this one is a report that cannot be
contradicted because the contradiction was already discarded.

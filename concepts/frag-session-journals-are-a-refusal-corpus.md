---
type: belief
id: frag-session-journals-are-a-refusal-corpus
provenance: 2026-09-28 side session mined sessions.db while a parallel session built wartrain in koru; corpus-first triage produced two verified bug pins the same day
ts: 2026-09-28
---

# Session journals are a refusal corpus — the compiler's negative space is already measured

Every agent session against koru logs each `koruc` refusal verbatim — the
diagnostic, the offending line, the fix that followed — in `sessions.db`. The
language's negative space is therefore not an open question: it is *recorded*,
ranked by frequency, and (via `taught`-miss flags) ranked by whether the message
taught anything. Guessing which grammar rule hurts most is obsolete; the corpus
answers it (chains ~29%, label↔pun seesaw ~16%, stores ~12% of all recorded
refusals).

The belief that replaces: "we learn what the language gets wrong by thinking
about it." No — the telemetry exists and was never read back. A transcript's
learned rule is a *hypothesis*: the same corpus both confirmed two real bugs
(the PARSE006 hint naming the wrong parameter; a `//` comment inside a
struct-literal schema fusing into the next field's name) and debunked a
confidently-stated wrong one (comments between `|>` steps break chains — they
compile; only comments *inside* blocks were reaching the scanner).

The instrument lives at `friction/` (`friction.py` scan/hist/lookup/pitfalls,
`timing.py` for refusal-episode dwell), the standing generator is
`challenges/028_the_friction_corpus`, and the discipline is: **after any
koru-touching session, re-run the scan; before believing any transcript claim,
re-measure it.** Every future session's refusals append to the corpus for free —
the loop measures itself.

Sibling instruments of the same shape (scons compiling a copy-tree, build
variants emitting empty artifacts) live outside `src/` but are the same genus —
worth mining when those toolchains hurt.

Related: [[frag-a-diagnostics-hint-is-a-claim-not-a-tested-path]] (the corpus is
what finds which hints are untested claims), [[frag-the-tested-half-of-a-rule-is-the-half-that-is-real]].

---
type: belief
id: frag-session-journals-are-a-refusal-corpus
provenance: 2026-09-28 side session mined sessions.db while a parallel session built wartrain in koru; corpus-first triage produced two verified bug pins the same day; evolved same day — corpus rescoped to invocation and provenance-tagged; evolved again — KORU010's 345 rows proved ~95% cascade, teaching that bursts not rows rank a family
ts: 2026-09-28
---

# Session journals are a refusal corpus — the compiler's negative space is already measured

Every agent session that runs `koruc` logs each refusal verbatim — the
diagnostic, the offending line, the fix that followed — in `sessions.db`. The
language's negative space is therefore not an open question: it is *recorded*,
ranked by frequency, and (via `taught`-miss flags) ranked by whether the message
taught anything. Guessing which grammar rule hurts most is obsolete; the corpus
answers it.

**Membership is by invocation, not by address.** The first cut scoped the corpus
to a cwd allowlist and silently missed 218 `koruc`/`run_regression` calls fired
from outside the family tree (`the-man` alone held 65 rows across 14 refusal
episodes). A row counts because the call compiled Koru — the compile is the
event; where the agent was standing is provenance, not membership.

**Provenance is a filter axis, not a deletion.** Every row carries `repo`, `org`,
`session`, `cwd`, `via`. A greenfield game's refusals measure a confused
newcomer, not the language — the working backlog is the systemic view
(`--without org:COCPORN,repo:ogun`), and re-ranking under it is not cosmetic:
KORU161 is 232 rows unfiltered but 126 systemic; PARSE006 was 280 but 55. Half
the first day's headline numbers were one game session.

**Row count overstates cause count — count bursts, not rows.** A refusal
family measured in runs is one cause amplified: KORU010's 345 systemic rows
decomposed to ~95% cascade — one severed chain orphaning every continuation
line below it, each line logging its own identical refusal. Split a family by
burst size and source shape before ranking it; a dominant cascade is a
diagnostic-amplification finding, not a count of distinct confusions. (Fixed
by collapsing the orphan run into one diagnostic that names the separator.)

The belief that replaces: "we learn what the language gets wrong by thinking
about it." No — the telemetry exists and was never read back. A transcript's
learned rule is a *hypothesis*: the same corpus both confirmed two real bugs
(the PARSE006 hint naming the wrong parameter; a `//` comment inside a
struct-literal schema fusing into the next field's name) and debunked a
confidently-stated wrong one (comments between `|>` steps break chains — they
compile; only comments *inside* blocks were reaching the scanner).

**The loop is the point — this is the improvement flywheel, not a snapshot.**
Sessions produce refusals → `scan` mines them → triage ranks by frequency ×
teach-miss × dwell → fixes land in the compiler → the next sessions' refusals
measure whether the teaching worked. The instrument lives at `friction/`
(`friction.py` scan/hist/lookup/pitfalls/report, `timing.py` for
refusal-episode dwell), the standing generator is
`challenges/028_the_friction_corpus`, and the discipline is: **after any
koru-touching session, re-run the scan; before believing any transcript claim,
re-measure it.**

Sibling instruments of the same shape (scons compiling a copy-tree, build
variants emitting empty artifacts) live outside `src/` but are the same genus —
worth mining when those toolchains hurt.

Related: [[frag-a-diagnostics-hint-is-a-claim-not-a-tested-path]] (the corpus is
what finds which hints are untested claims), [[frag-the-tested-half-of-a-rule-is-the-half-that-is-real]].

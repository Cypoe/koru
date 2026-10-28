---
type: belief
id: frag-no-verdict-must-not-fold-into-verdict-was-no
provenance: the .kz→.k migration gate, 2026-08-09. It enumerated 38 candidates, handed only 33 to the runner because its filter was built from a leading `NNN_NNN` that five directory names do not have, and reported those five as "no marker — never ran". A two-state gate would have counted them as "stays .kz" and printed a smaller, healthier backlog
ts: 2026-08-09
evolved: 2026-10-28 — new instance species: the zero-byte TODO marker — a sideline bucket that holds nothing and still counts (020_067, 030_017, 400_195 un-silenced to red)
---

# A backlog is only a backlog if the gate can say "I did not judge this"

A gate that classifies each candidate as pass-or-fail has two buckets and needs a
third. The missing one is **"produced no verdict"** — the candidate that was
enumerated, counted in the denominator, and then never actually run, because a
filter, a name pattern, or a skipped setup step dropped it on the way to the
oracle. With only two buckets it lands in whichever one is the absence of a
marker, and for a migration backlog that is *"correctly stays where it is"* — the
answer that makes the number go down.

**That is the direction the error always runs, and it is why this is worth a
fragment.** A dropped row does not produce a scary result; it produces a *better*
result. The backlog shrinks, the sweep looks more finished than it is, and the
next session reads "mined out" and stops looking. Nothing about the output
distinguishes a candidate that was tried and passed from one that was never tried
at all — unless the gate refuses to collapse them.

The concrete instance: the gate ran per-candidate by extracting a leading
`NNN_NNN` from each directory name, and five candidates are named with one number
rather than two. They were never handed to the runner. The gate said so, in its
own section, and exited non-zero — which is the only reason the miss was visible
at all, and the reason the earlier belief that this backlog was "mechanically
mined out" has to be qualified: part of that conclusion rested on candidates
nobody had tried.

**And the dropped rows are not a random sample of the set they fell out of.**
When the five were finally judged, all five converted — against 15 of 33 in the
population the gate could reach. The rate in the invisible subset was double the
rate in the visible one, and that is not luck: they were dropped by the *shape of
their names*, the naming convention tracks roughly when a test was written, and
when a test was written is exactly what predicts whether it was authored as pure
Koru. The filter selected on something correlated with the answer.

So the cost of a silent drop is worse than its size suggests. "Five of thirty-eight
went unjudged" invites the estimate that half of five would have converted; the
truth was all of them. Any correction that assumes the missing rows behave like
the measured ones is guessing with the same bias that produced the gap.

Sibling to [[frag-a-check-that-cannot-match-reports-clean]], which is about a
check whose *pattern* cannot match and therefore reports nothing. This one is
about a check whose pattern is fine but whose *worklist* silently loses rows
between enumeration and judgment. Both report health; only one of them is
detectable by reading the predicate.

**The fold lives one layer deeper, too — in the input fetch.** Measured
2026-10-02 on the git-gate port (challenge 030 replay 1): `std/gate`'s
staged-diff read rides `Child.run`'s 50KB `max_output_bytes` default, so a
60KB diff — inside the 96KB judge window — errors the fetch, `staged` stays
null, and every judged row takes the empty-state path — "no staged changes" —
a true-absence verdict for an error-shaped absence. The port even *contains* the third bucket (an UNJUDGED
branch for states over the 96KB judge window) and it is unreachable: the cap
strangles the input before the window check runs. The oracle (gate.py) reports
UNJUDGED and blocks; the port reports clean and exits 0. Same law, one layer
down: not only must the gate distinguish "never judged" from "judged no" — it
must distinguish "the state never arrived" from "the state was empty."

2026-10-28 instance, a different silence species (challenge 016 replay): three
test dirs carried a TODO marker that was **zero bytes** — sidelined, counted in
the denominator's exclusion, carrying no reason at all (020_067, 030_017,
400_195). The marker existed, so no scanner row read "never ran"; the reason
field folded into silence instead. Measured, all three pin live defects — two
stage-D emitter bugs and a silently-dropped arm — so the state the marker
asserted ("deferred, unrun") was wrong in fact: each is a red the board was not
reporting. Empty-marker is the smallest member of the family: not "no verdict
bucket", but a bucket that holds nothing and still counts.

**What would correct this:** a case where the third bucket is noise — where
"never ran" is routine and expected, and forcing the gate to fail on it trains
everyone to ignore the exit code. Then the third state has become decoration and
the honest move is to fix the enumerator instead of reporting the gap.

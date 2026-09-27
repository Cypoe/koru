---
type: belief
id: frag-a-signal-that-does-not-float-is-not-a-signal
provenance: measured twice — 2026-09-22 (three boards ran while the Discord post froze at 1818 because the publish invocation was never wired) and 2026-09-26 (a foreign parser commit reddened 210_133 mid-board; the red printed on transcript line 609 of ~2500 and nothing floated it — it surfaced only because Lars asked whether the ceremony had seen it)
ts: 2026-09-26
---

# A signal that requires proactive grepping fails the same way as no signal (belief)

The board measured everything correctly both times. What failed was not the
instrument — it was the last hop, the delivery to an observer. A red on line
609 of a 2,500-line transcript is information-theoretically identical to a red
that never ran: the number of eyes on it is zero until someone goes looking.

The same shape fired twice in one week: boards that ran but never published
(the invocation was never wired, fixed by `publish_board_to_site`), and a
regression that printed but never floated (fixed by posting
`koru.regression.fail` to sidetrack at the moment each test falls, plus an
automatic `diff-snapshots` delta against the previous board — the opt-in
`--diff` flag existed and was never invoked, which is the same failure one
level up).

The ruling: **delivery is part of the instrument, not a notification about
it.** A wall, a suite, or a watcher whose output lands only in a transcript
is unfinished. The question to ask of any instrument is not "does it fire?"
but "where does the firing land, and who is in that room?"

Corollary for concurrent sessions: with several sessions committing against
one tree, the global invariants (duplicate pin ids, a foreign commit moving a
diagnostic out from under a pin) are only visible to the board — so the
board's failures are the ones that most need to float.

## Second instance — a floated instrument can still measure nothing (2026-09-27)

The board delta added the same day *did* float — it printed a section and
posted an event — and it reported "No changes detected" on a board where a
test had flipped red→green and a new pin had landed. The cause:
`diff-snapshots.js` computed "current" through `generate-status.js`, which
prefers `test-results/latest.json` — the previous snapshot — when it exists.
The instrument compared the old board to itself; the delta was structurally
incapable of seeing a change. (A second wound beneath it: the filesystem
fallback only recognized `input.kz`, so even a real scan saw a 947-test
shadow of the 2,191-input corpus.)

The widened claim: delivery is necessary but not sufficient — **the reading
has to be of the world, not of the instrument's own memory.** A comparator
wired so its two inputs are the same source is a gauge whose needle is
pinned to zero; it will print "no change" on every board and look like the
instrument working. Verified means a fixture with a *known nonzero delta*,
not a self-comparison that cannot fail.

## Falsification / open edge

If floats become noise — every filtered run spamming the sink — the signal
dies the other way, drowned rather than stranded. The scope tag (`board` vs
`filtered`) exists so a reader can weight them; if that proves insufficient
the float needs rate-shaping, not removal.

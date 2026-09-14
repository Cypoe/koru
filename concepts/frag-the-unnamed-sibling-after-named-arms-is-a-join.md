---
type: belief
id: frag-the-unnamed-sibling-after-named-arms-is-a-join
provenance: koru-libs asteroids-net watcher.k segfaulted inside udp:close — the auto-discharge inserter had grafted the socket's discharge inside BOTH `| then` and `| else` and emitted the author's `|> close` again at the join; the fix (join_watermark in the inserter, join_live_obligations in the phantom checker) is what fell out, pinned by 400_193
ts: 2026-09-14
---

# The unnamed sibling after named arms is a join — inherited obligations are live-through it, and both passes must agree (belief)

A continuation list `[then, else, |> next]` is not three alternatives. The named
children are exclusive arms; the **unnamed child is a join** — emitted once,
after whichever arm ran. Its position in the list is what `if` means.

The obligation consequence is a watermark, not a flag: an obligation inherited
at arm entry is live-THROUGH the arm (the join still holds it); an obligation
born inside the arm is the arm's own and must settle at the arm's leaf.
Acquisition order is the whole distinction — `acq_seq < watermark` is
live-through, `>=` is arm-local. The named/unnamed shape of the sibling list
is the only signal needed; nothing else about the arm matters.

## The durable claim: insertion and enforcement are one judgment made twice

The inserter and the phantom checker walk the same AST asking the same
question — is this leaf an exit for this obligation? — and they must answer
identically. When they disagreed here, the failure did not land at compile
time: the inserter grafted discharges the checker never complained about
(because they were present), and the defect surfaced as a runtime double-free
three processes deep into a UDP test. **A two-pass obligation discipline can
only fail silently where the passes diverge — divergence IS the bug class.**
Every future liveness rule belongs to both passes or to neither.

## What it cannot yet absorb

Escape is still absolute: an arm that ends in a terminator never reaches the
join, so join-live obligations must still settle on that path — the watermark
must not leak into terminator handling (it doesn't; explicit exits keep the
unfiltered view). Back-edge jumps inside a join arm are unmeasured — a jump
that bypasses the join while holding a live-through obligation has no pin.

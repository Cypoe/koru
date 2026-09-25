---
type: belief
id: frag-a-gate-row-that-rolls-is-an-alarm-not-a-schedule
provenance: 2026-10-13 — designed at the close of the deslop campaign: the census flywheel depended on a session remembering to run it, and the fix chosen was a tag-declared firing probability on the invariant row rather than a scheduler
ts: 2026-10-13
---

# A gate row that rolls is an alarm, not a schedule (belief)

Deferred-hygiene work dies by postponement, not by refusal — nobody decides
against it, sessions just stop reaching for it. The remedy is not a cron job:
a schedule fires on wall-clock time whether or not the artifact is moving,
and its report lands where nobody is looking. The remedy is a *sampled gate
row*: the check fires inside the mutation event itself, on a roll of the
staged diff, so the alarm can only ever sound when there is a diff in hand to
answer it.

## The declaration is a tag; the mechanism is the interpreter

`odds-N` on a git-gate row declares firing probability the same place firing
scope already lives — `git-gate` vs `git-gate-local` were always tag-level
routing, so sampling is one more datum on the row, not a new construct. The
roll itself belongs to `gate.py`, the interpreter. A `std/chance` spelling
was considered and refused for now: it would invent language surface for a
scheduling concern the manifest parser never sees — and `surface-spellings-
are-ruled` exists precisely for recognized forms nobody ruled. The name is
earned the day a *second* interpreter shares the roll, not before.

## Determinism is what makes it reviewable

The roll is `sha256(row name + staged diff) mod 100` — fixed for a given
staged state, unpredictable only until the diff exists. A gate that rolled
true randomness could not be re-run to reproduce a verdict; a deterministic
roll can. Unpredictable-before-staging is also the anti-gaming property: you
cannot write the diff to dodge the alarm without changing the diff.

## What sampling may not touch

A sampled **check** row keeps the gate honest: when it fires it either passes
or blocks on concrete script output. A sampled **judged** row is a different
and worse thing — an oracle that sometimes blinks, which erodes the standing
of every row around it. `odds-N` lives on `check:` rows.

## The instrument can name the repo it measures

A `check:` row was koru-scoped by construction — the manifest lives there,
so its instruments measured only that tree. `repo-<name>` extends the row
one field further: the check fires only when the gate is gating that repo,
letting one manifest hold alarms for every consumer wired through
`--repo`. The first use pins koru-libs' `.kz` corpus — the family's
second-largest hand-written tree, which had never had a clone instrument
because the census spoke only Zig. The .kz census runs through
`koruc --ast-canon` rather than a new parser: the instrument you need
usually already emits the surface.

## Open

Whether a firing alarm should emit a durable signal beyond the gate's stdout
(a WMFX event, a board entry) — currently the only record is the commit log
it fires inside. Whether the pin-and-compare shape generalizes past the
deslop census to other regrow-able measurements (test-fixture counts, doc
staleness) is unmeasured.

---
census: std/bridge
measured: 2026-09-11
against: koru main eff5d83cd
consumers: ~4,000 .k/.kz files — koru suite, koru-libs, kopium, orisha, misc ~/src
---

# std/bridge — the kopium spine: designed core, three prompt-renders

3 files: `bridge.kz` (Bridge struct + create/get-handles/define/vocabulary/
grammar/close) + `bridge.run.kz` + `bridge.affordances.kz`. One namespace
declared `~[comptime|runtime]` — plain `~proc` tors, no transform layer;
what you see in the pub list is what exists.

## The table

| tor | classification | evidence |
|---|---|---|
| `run` | live | 331 sites; the turn verb — 11-branch honest result incl. `?partial` (partial programs), `event-denied`, `parse-error` |
| `create` | live | 168 sites; returns `*Bridge<session!>` — the obligation phantom |
| `grammar` | live | 57 sites; the prompt render the head actually uses (kopium's `wire:warm-grammar` wraps it) |
| `close` | live | 49 sites; `*Bridge<!session>` consumes the obligation |
| `vocabulary` | live — probe-tier | 47 sites, nearly all probes/tests; the static surface render |
| `define` | live — probe-tier | 5 sites (440_008/009/012 tests); the agent-facing path goes through `run`'s `\| defined` branch, not this tor |
| `affordances` | live — probe-tier | 4 sites, all `probe_affordances.k`; the possession-shaped "what can I call NOW" render (HATEOAS rooms) — exists, exercised, never shipped in a real prompt |
| `get-handles` | **dead** | 0 sites, nothing emits it; `close`'s own doc says "there for anyone who wants the count" — nobody wants it. `run`'s branch payloads already carry `handles: u32`, so the count arrives without a tor. **→019** |

`Bridge` (352) and `session` (52) are type/phantom refs, not tors.

## Seams

- **Three prompt-renders, one in use.** `vocabulary` (static surface),
  `grammar` (rules + compiled + inventions), `affordances` (possession-shaped
  callable subset) all produce a string for the prompt. The head uses
  `grammar`; `vocabulary` is test scaffolding; `affordances` — arguably the
  most interesting render, "given what I hold, what is legal" — is a probe
  nobody ships. Three render tors is the evolved layer on a designed core.
  **task** — a ruling on which render is *the* prompt surface (or whether
  affordances' possession-shape belongs INSIDE grammar's output).
- **`define` the tor vs `run`'s `| defined` branch** — two doors to the same
  machinery: direct call (5 sites, all tests) vs. the agent path through
  `run`. Probably intentional (tests need the direct door), but the pub
  surface says both are equal-rank and they aren't. **task** — mark or
  narrow; a one-line doc decision.
- **`budget` is parked** — `run`'s own header: metering deliberately not
  forwarded, "earns its keep on a public-facing API." A documented absence,
  not a gap — but worth naming so a future census doesn't re-find it.
  **task** — when cost control lands (the pre-chain spend question), this is
  where it plugs in.
- **One real consumer.** Outside tests/probes, `std/bridge`'s entire call
  mass is kopium — the harness is the spine's only application, which is the
  intended shape (KOPIUM is the forcing function) but means every semantic
  claim here is backed by a single tenant. **task** — a second consumer
  would falsify the surface's generality faster than any review.

## Verdict

Designed core, evolved perimeter — the obligation phantoms
(`session!`/`!session`), the honest 11-branch `run`, and the possession
enforcement are the designed spine; the three-render pileup and the dead
observability tor are the accretion on top.

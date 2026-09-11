---
census: std/runtime
measured: 2026-09-11
against: koru main 71a9c541e
consumers: ~4,000 .k/.kz files — koru suite, koru-libs, kopium, orisha, misc ~/src
---

# std/runtime — the register/run spine, plus an introspection pileup

5 files: `runtime.kz` (register + scope introspection + explain) and
`~part`s `run`, `eval`, `parsewire`, `affordances`. All plain `~proc`s —
but this organ demonstrates **three more reachability flavors** beyond
call sites: sibling-zig calls, explainer-gather, and dormancy.

## The table

| tor | classification | evidence |
|---|---|---|
| `register` | live | 122 sites; the vocabulary-declaration front door |
| `run` | live | 60 sites; single-turn execute (`[retain]`) |
| `scope-vocabulary` | live | 46 sites; static surface render |
| `parse.wire` | live | 10 sites; the wire gate (`?partial` lives here per run's header) |
| `eval` | live | 10 sites |
| `parse.source` | live | 8 sites |
| `get-scope` | live | 5 sites |
| `scope-manifest` | live | 4 sites; the served JSON contract |
| `scope-grammar` | live | 2 sites |
| `run-cached` | **dormant** | 0 sites; the *richer* run — `?budget`, `handle_pool`, `shape`, `lenient`, `fail_fast`, `auto_discharge` params — that nothing calls. Wraps `interpreter:run-cached`. |
| `scope-affordances` | **sibling-internal** | 0 Koru call sites; invoked from `bridge.affordances.kz:77`'s zig body (`scope_affordances_event.handler`). Pub-ranked but reachable only through a sibling proc. |
| `explain-runtime` | **compiler-emitted** | `[comptime|explainer]` — koruc's `koru_explain_gather` invokes every discovered `[explainer]`; no program ever spells it |

## Seams

- **The introspection pileup mirrors bridge's render pileup** —
  `scope-vocabulary` (46) / `scope-grammar` (2) / `scope-affordances`
  (sibling-only) / `scope-manifest` (4): four scope-rendering tors, and the
  bridge layer re-projects three of them (`vocabulary`/`grammar`/
  `affordances`). Two layers of near-parallel renders is where "evolved"
  shows. **task** — one render-vocabulary ruling across both layers; the
  005_bridge entry's three-render seam is this one's twin.
- **`run` is thin and adopted; `run-cached` is rich and dormant** — the
  param-rich path (budget! handle_pool! lenient! fail_fast!) lost to the
  one that isn't. If per-turn parse caching ever matters — kopium re-parses
  every turn — the tor already exists. **task** — `bridge:run` delegating
  to `run-cached` is the un-adoption to revisit when cost control lands.
- **`scope-affordances` is pub but only sibling-reachable** — a pub tor
  whose only caller is another tor's zig body is surface that reads public
  and behaves private. Same costume problem as `[norun]` impls, different
  mechanism. **task** — joins the surface-honesty ruling.
- **`explain-runtime` is gathered, not called** — the `[explainer]` marker
  does the honest thing (the comment names the emitted reference), but it
  means pub-ness here means "visible to the driver." **task** — the same
  visibility ruling covers this too.

## Verdict

Designed spine (`register`/`run`/`parse.*`), evolved introspection
perimeter — and the dormant `run-cached` is the sleeper finding: the
configurable execution surface already exists, just unplugged.

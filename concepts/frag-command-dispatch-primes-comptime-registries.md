---
type: belief
id: frag-command-dispatch-primes-comptime-registries
provenance: koru-libs `stack` spike (2026-10-03) — a [comptime|command] probe
  reading build:config printed MISSING under every flag; the registries are
  populated by a pass commands never reach. Fixed in main.zig, pinned 310_133.
ts: 2026-10-03
---

# Command dispatch must prime comptime registration before any handler runs (belief)

`koru_command_dispatch` returns early — for a command, dispatch IS the whole
backend path, and the pipeline's Phase 2.3.5 `comptime_main` pass never runs.
That pass is what registers `build:config` / `build:variants` into
`emitter_helpers`, so `getBuildConfig` / `getVariant` — public and
re-exported "so userland code can query" — were empty inside every command
handler that ever ran. A published read API whose values only exist on a path
commands cannot reach: the contract held on paper, never in a process.

The rule this mints: **whatever a command handler needs from pipeline
registration state must be established at dispatch**, because nothing after
dispatch gets a chance. `koru_command_dispatch` now runs `comptime_main`
before invoking a handler — return value discarded, the prime is for registry
side-effects; handlers keep the seed AST they always saw. The codebase's own
wart comment (the 2.3.5/2.5 double-run, "the cleaner fix is a dedicated
pre_transform_main()") names the deeper shape; the prime is compatible with
that segregation whenever it lands.

Same failure family as the step-graph swallow: two paths that look like one
pipeline, and a contract that only holds on the path commands never take.

Related: [[frag-a-command-and-the-build-step-graph-are-disjoint-paths]]
(the sibling case — the frontend step graph swallows the command verb;
this one is the backend pipeline swallowing the command's registry state).

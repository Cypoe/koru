---
type: belief
id: frag-a-comptime-site-persists-through-a-registry-not-the-ast
provenance: std/spec:claim slice, 2026-10-27 — first draft harvested
  claim sites from ctx.ast in the analysis pass and measured zero; the
  site had been stripped by elaborate Phase 3 before analysis ever ran
ts: 2026-10-27
tags: [koru, comptime, elaborate, registry, claims]
---

# A comptime site's data reaches analysis through a registry, not the AST (belief)

A `[comptime|norun]` site flow has a designed lifecycle: `comptime_main`
executes it during elaborate Phase 2.5, and Phase 3 rebuilds the AST
*without* flows that invoke comptime decls. By `pass-*` analysis time the
site is gone — `ctx.ast` holds no trace. A pass that walks the AST for
such a site will measure zero and report nothing, cleanly wrong.

The persistence channel is the `build:config` pattern: the site's decl
carries a `[comptime]` proc that runs when `comptime_main` executes the
site, and that proc **writes a registry entry** (keyed by
`InvocationMeta.location` for dedup — `comptime_main` runs twice). The
analysis pass reads the registry. `pass-claims-check` is the second
consumer of this pattern; `run-pre-transforms`-time harvesting is only
correct for data a transform needs before comptime evaluation.

The rule: **before designing where a site is read, know which phase
removes it.** A flow-shaped site is executed-then-stripped; its data
must be flushed to a side channel during execution, because there is no
later moment where both the site and the reader coexist. Same family as
the command-dispatch prime (`frag-command-dispatch-primes-comptime-
registries`): registry state only exists on paths that actually ran the
phase that populates it.

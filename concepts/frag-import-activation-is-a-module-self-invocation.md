---
type: belief
id: frag-import-activation-is-a-module-self-invocation
provenance: koru session 2026-09-14 — std/refine spike; 110_035 pins the mechanism for an arbitrary user-defined transform (ccp.kz's `~tap(* -> *)` is the production precedent)
ts: 2026-09-14
tags: [koru, modules, imports, transforms, comptime, metaprogramming]
---

# Import-activation is a module self-invocation: importing a module can install behavior with no call site (belief)

A transform tor *declared inside* an imported module fires at Stage C purely
because the import landed its invocation in the program tree — the pass runner
walks `module_decl` items for transform sites (`ASTNode.children` descends
module items) and `replaceFlowRecursive` writes the result back into the
module. `import std/taps` only arms a keyword; a module carrying
`~install(...)` at top level activates on import alone. `ccp.kz`'s
`~tap(* -> *)` has done this in production; 110_035 pins it for an arbitrary
transform, which is the mechanism ambient `Source`-block grammars (a future
refine-that-intercepts-other-blocks) would ride on.

Two sharp edges, both measured:

- **Self-replace, never decline.** A declined `SiteResult` calls
  `removeFlowFromProgram`, which scans *top-level* items only — a
  module-nested site that returns empty survives as a dead runtime call.
  Always return `.replacement`.
- **Activation is global; effect must be scope-filtered.** The install flow
  fires once per program, but an ambient rewrite must descend only into
  scopes whose `import_decl` items name the activating module —
  `module_decl.items` retain their imports post-combine, so the filter is a
  scan, not an architecture. Non-transitive: A imports refine, B imports A →
  B's blocks are untouched. Match canonical module identity, never the
  written spelling.
- **Transform tors can live in `.k` — but only if the signature avoids host
  types.** The ABI binds params by name into a synthesized `Input` struct;
  declared types emit verbatim, so `allocator: std.mem.Allocator` is
  unspellable without a `.kz` host line importing `std`. Omit the param and
  take `@import("std")` inside the proc body; allocate through
  `koru_allocator()`, the accessor emitter_helpers emits into every module —
  it rides the Debug leak counter, unlike a bare `page_allocator`.
  `Expression`, `Source`, `std/compiler:*`, `SiteResult` are all Koru-level
  spellings that map.

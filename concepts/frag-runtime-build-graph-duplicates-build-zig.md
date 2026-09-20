---
type: belief
id: frag-runtime-build-graph-duplicates-build-zig
provenance: found while taking 440_RESOURCE_BRIDGE from red to green — the cross-session discharge pin was failing partly on a missing `struct_literal` module that build.zig had wired years-of-commits ago; widened 2026-09-07 when the same drift bit compiler.kz's backend table during the matchGlob lift-then-delete
ts: 2026-07-25
---

# The runtime's build graph is a hand-copy of `build.zig`, and it drifts silently

There are at least **three** copies of the compiler's module graph, and none
of them check each other:

1. `build.zig` — builds `koruc`. Feedback is instant: forget an import here
   and the compiler will not build.
2. `koru_std/compiler.kz` — the `~build:requires` Zig snippet emitted
   verbatim into every consumer's generated `build_backend.zig`, wiring the
   module table the backend `zig build-exe` is invoked with. Feedback is
   deferred: nothing compiles it until some program's backend build runs.
3. `koru_std/interpreter.kz` — another `~std/build:requires` block that
   hand-constructs a module graph (`errors`, `ast`, `lexer`, `type_registry`,
   `expression_parser`, `parser`, `flow_parser` and friends) rooted at the
   *installed* compiler (`REL_TO_ROOT = "/usr/local/lib/koru"`), for programs
   that import `std/runtime` or `std/interpreter`.

Plus the tracked emitted snapshots (`koru_std/build.zig`,
`koru_std/build_backend.zig`), which are compiler.kz's graph rendered to
text — they go stale the moment compiler.kz moves and nothing regenerates
them on demand.

Measured twice:

- 2026-07-25 (interpreter.kz): a Stage-D Zig error naming a module that
  "is not available within module 'koru_parser'", inside a `zig build-exe`
  command line, in a test whose subject was resource bridging. Nothing
  pointed at the `requires` block.
- 2026-09-07 (compiler.kz): `ast.zig` gained `@import("glob_pattern_matcher")`.
  `zig build` green, `zig build test` green, gate checks green — and
  `koruc invariants.kz invariants` failed at backend build with
  `no module named 'glob_pattern_matcher' available within module 'ast'`,
  naming the generated `-Mast=...` command line. The repo `build.zig` wiring
  was correct; the *emitted* table was not. The gate's own manifest compile
  is what surfaced it — a consumer had to run before the copy confessed.

The invariant, until the duplication is gone: **when a `src/` module gains an
`@import`, every hand-copied graph that includes that module needs the same
edge.** For compiler.kz that means `addImport` in the emitted table (and the
two tracked snapshots synced); for interpreter.kz the `requires` block's
per-module imports must stay a superset of that module's `@import`s. When
touching either side, diff them — and verify with a real consumer compile
(`koruc invariants.kz invariants` is the cheapest one), because `zig build`
cannot see copy #2.

Open, and the real fix: there should be one graph, not three — the
`build:requires` blocks should be generated from the same declaration
`build.zig` uses. A duplicated graph that only one side exercises is a trap
that resets every time the compiler's own module list moves.

Related: [[frag-zig-build-does-not-compile-all-of-src]] (the sibling fact —
`zig build` certifies the binary, not `src/`, and three files live only in
copy #2), [[frag-compiler-flags-baked-into-backend]] (the other place the
metacircular pipeline's two halves disagree about what is baked and what is
resolved).

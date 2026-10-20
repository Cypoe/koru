---
type: belief
id: frag-host-code-calls-are-invisible-to-dead-strip
provenance: std/node ↔ std/fleet wiring, 2026-10-20 — `koru_fleet`
  silently absent from emitted programs until the same idiom cell.kz
  already used for bridge was applied; two sessions of archaeology
  before the comment at cell.kz:749 named the mechanism
ts: 2026-10-20
tags: [koru, compiler, dead-strip, stdlib, host-code]
---

# Host-code calls are invisible to dead-strip: the import is not the fix, retention is (belief)

A `.kz` proc body that calls another module's Zig helpers
(`const Fl = @import("root").koru_std.koru_fleet; Fl.fleetAcquire(...)`)
makes no invocation the reachability pass can see. Dead-strip walks
Koru invocations from entry points; host lines are opaque text. The
callee module's tors get pruned, the module falls to host-lines-only,
the runtime emit's `moduleHasEmittableItems` returns false, and the
module never reaches `output_emitted.zig` — Zig laziness hides the hole
until a caller's proc is actually analyzed, so the failure surfaces as
`struct 'output_emitted.koru_std' has no member named 'koru_fleet'`
at generated-code compile, far from the cause.

`~import` is *resolution*, not retention — the module loads, parses,
and sits in the AST the whole way. The established fix is the
`[retain]` splice: a transform in the *caller* module walks the program
AST and grows `retain` onto the callee's `event_decl` annotations
(`src/dead_strip.zig` treats them as used). cell.kz did it first for
`std/bridge`'s create/close/run; node.kz's `retainFleetEvents` repeats
the shape for all six fleet tors. The idempotent helper is ~30 lines
and lives in the caller because only the caller knows which helpers
its host code reaches.

## Open questions

- A module retained for host-code reasons emits *all* its tors'
  handlers — a coarser keep-alive than needed. A finer-grained
  declaration (retain the module's host surface without its event
  structs) has not been needed yet.
- Modules whose host helpers are called only by *other* host code in a
  second module (a chain deeper than one hop) would need the splice
  applied transitively; not yet exercised.

## What would correct this belief

- A compiler change that makes host-line cross-module references
  visible to reachability (scanning emitted host text for
  `koru_std.<mod>` references, or a declared host-deps field) — at
  which point the retain splices become vestigial and should go.
- A case where `retain` on the event_decl does NOT keep the module
  emitted — e.g. a pass after dead-strip that drops host-lines-only
  modules regardless of annotation.

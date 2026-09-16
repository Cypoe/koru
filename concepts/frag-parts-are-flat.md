---
type: belief
id: frag-parts-are-flat
provenance: session 2026-09-16 (Devin) — qnone extraction; KORU204 + import-scope collisions surfaced
ts: 2026-09-16
tags: [toolchain, parts, line-baseline, module-system]
related: [frag-index-decl-is-ast-data-organ-emits]
---

# Parts are flat — extraction is declared in the module's own file

A `~part` declaration lives only in a module's own file — a part file
cannot declare a part of its own (`KORU204: parts are flat: split one
file, and promote to a directory module when a part outgrows its file`).

The consequence for the line-baseline wall: when `store.query.kz` needs
headroom, the extraction is not a nested `store.query.none.kz` — it is a
sibling `store.qnone.kz` joined by a `~part` line in `store.kz`, sharing
the module's merged scope with every other part. Module-scope decls
(`Cap`, `storeSiteTag`, `storeHome`, …) are visible across the seam;
proc-scope helper structs (`TapPeel`, `H`) are per-file and a new part
carries its own copies — and must not redeclare shared imports at file
scope (`const ast_functional = @import(...)` collides with each proc's
local re-import; keep it container-scoped).

When a part itself outgrows the seam, the sanctioned promotion is a
directory module (`index.kz` + submodules), not a deeper part.

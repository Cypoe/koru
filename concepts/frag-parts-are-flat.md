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

The seam has a second-order consequence for every derived instrument: **a
filename is not a module name.** `scripts/js-parity-map.mjs` listed
`koru_std/` flat and registered `store.new.kz` as a module named
`store.new` that no import can spell; every `store:*`/`list:*` call site
then resolved against the primary alone, missed, and 27% of the corpus
landed in its unresolved tail — the map's own DO-NOT-TRUST verdict. The
flat read failed quietly: it produced self-consistent wrongness rather
than an error, because the phantom modules it minted are real files
holding real procs. Any tool that maps the stdlib surface by listing the
directory must join `<module>.<part>.<facet>` files on the primary's
`~part` lines — the declaration is the only authority, and the join is
declaration-gated (an undeclared dotted file stays its own unimportable
name rather than being silently attached).

**2026-10 — the seam has a naming law too: a lifted name must be unique
across the whole merged module.** Zig does not let an inner decl shadow
a module-scope one — a `const H` at module scope and a `const H` inside
any sibling namespace (`PSweep`, a proc body) makes every `H.` reference
ambiguous, an error, not a resolution. So a proc-local helper lifted to
a part under its short name detonates every sibling that ever declared
the same short name. The wall-driven store splits surfaced it:
`store.new`'s proc-local `H` became module `HomeScan`, its second `Walk`
became `CellWalk`, and every sibling part's own `const H` had to be left
in place rather than unified. Extraction is not "cut decls, paste
elsewhere" — it is "cut decls, rename until the name exists nowhere else
in the module."

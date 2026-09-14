---
type: belief
id: frag-comment-markers-are-the-inter-transform-wire
provenance: koru session 2026-09-15 — Lars demanded the full audit after discovering std/refine copied proto's `//`-marker convention. Measured against the tree at main, post-75dfa3c03/a62e146f9.
ts: 2026-09-15
tags: [koru, transforms, comptime, markers, architecture, audit]
---

# `//`-comments are the inter-transform wire — full audit (belief)

**The substrate:** a transform's declaration doesn't survive its own
rewrite, so several stdlib modules replace a flow with an `inline_code`
item whose text is a `//`-comment — and *other transforms (or the
compiler) scan that comment text to recover the data*. It is a
stringly-typed, comment-carried registry living in `program.items`.

**Lars's ruling on the boundary (2026-09-15):** `//` text in *emitted
Zig output* is fine — cheap pdb-equivalent debug info. The problem is
`//` as a *signal carrier between compiler stages*: one pass writes a
comment, another pass parses it. Everything below is the second kind.

## Family A — data payloads: a comment carries a record another pass parses

| Marker | Writer(s) | Reader(s) | Carries |
|---|---|---|---|
| `// proto Name: f: t, …` | `proto.kz:416`, `types.kz:166` | `proto.kz:145,292` (self), `list.free.kz:184,279`, `store.kz:538,644`, `store.new.kz:525`, `refine.k:350` | compound decl: name + flat fields |
| `// proto-terminal Name: T` | `proto.kz:467,518,569,620` | `proto.kz:128`, `store.new.kz:418` | scalar terminal name + host type |
| `// foreign Name: f1, …` | `foreign.kz:112` | **`src/type_registry.zig:871`** — compiler core parses a stdlib comment | foreign decl fields |
| `// store-kinds …` | `store.new.kz:3133` | `store.kz:563` | store kind arms |
| `// store-member-types …` | `store.new.kz:3146` | `store.kz:721` | store member types |
| `// store-view …` | `store.view.kz:62` | `store.kz:1183,1316,1341` | store view decl |
| ~~`// refine home:Name: …`~~ | ~~`refine.k`~~ | ~~`refine.k`~~ | **MIGRATED** — first namespace off the wire: now `Item.facet_decl` (typed node: `name`/`module`/`fields` with structured `lo`/`hi`/`eq` bounds). The emitter still *renders* `// refine …` into generated Zig — write-only debug output, never parsed back. |

## Family B — sentinel flags: a comment marks a generated block

| Marker | Writer(s) | Reader(s) | Means |
|---|---|---|---|
| `//@koru:inline_stmt` | 24 sites: `parser.kz:153,737`, `regex.kz:92,426,622,824`, `testing.assert.kz:41`, `trellis.kz:402`, `field.kz:678`, `switch.kz:69`, … | `emitter_helpers.zig:13314` (mutual-group lowering gate), `dead_strip.zig:397` (cargo exemption) | "this inline_body is a lowerable inline statement — don't strip, lower differently" |
| `// __KORU_RUNTIME_REGISTRY_HELPERS__` | `runtime.kz:890` | `runtime.kz:91` (scans `host_line` content — dedup: "helpers already emitted?") | presence flag on a generated block |

## Tombstones — write-only, nobody scans (legal under the ruling)

`// std/store: '<name>' created …` (store.new.kz:5882,7048),
`// std/store: watch(...) spliced …` (store.watch.kz:264),
`// std/pump: pump '<n>' created …` (pump.kz:436),
`// branch constructor: …` (main.zig:4528),
`// \`<x>\` is not exported …` (visitor_emitter.zig:4559).

## Benign comment handling — stripping/skipping, not signal (NOT the wire)

`parser.zig:1249,1766,2317,4042,4147,10910,11289`, `main.zig:6574`,
`ast_printer.zig:74`, `emitter_helpers.zig:5310,6467`,
`runtime_registry.zig:94`, `vendor.kz:93`, `runtime.kz:380`,
`dead_strip.zig:398` — ordinary comment-stripping in lexers/emitters.

## What each edge holds up

- `// proto` → `list.free` container synthesis (fields for `List_<Name>`),
  store decl typing, proto's own cross-module resolution. Removing it
  breaks ~all of 665_* and every proto-list/store test.
- `// proto-terminal` → terminal identity resolution (665_*),
  `store.new` member typing.
- `// foreign` → `type_registry` field lookup for foreign types —
  the only edge where `src/` consumes a comment.
- `// store-kinds`/`member-types`/`view` → store.kz's kinded-leaf and
  view machinery (690_*).
- `//@koru:inline_stmt` → mutual-group lowering in the emitter +
  dead_strip's don't-strip rule. Removing it silently changes codegen.
- `__KORU_RUNTIME_REGISTRY_HELPERS__` → runtime.kz emitting its helper
  block exactly once.

## Lineage — who started it

**`ac09f6d5c` (2026-03-29), "feat: add type system regression tests and
kernel scope PDRs"** — the generics/type-mint work in `koru_std/types.kz`.
A transform emitted `// __GENERIC__:Option<T>:{ some: T, none }` into
`inline_code` and a later pass scanned `ic.code` for the prefix to
recover "already transformed" declarations. Same motivation as every
later use: ordering across dissolution.

Propagation:

- **Aug 23** — `9a6dca3f3` dissolved `__GENERIC__` (the type-mint
  cutover) and *the same day* `54b465b0d`/`3389c4f4b`/`cba51de03`
  introduced `// proto` for proto→list synthesis. The idiom was copied
  into proto at the moment its original carrier was being removed.
- **Sep 3** — `18ca2ce69` added `// proto-terminal` + the
  `markerDeclares*` scanners; `7333249fe` added `// foreign` — including
  the `src/type_registry.zig` reader, the only edge where compiler core
  parses a stdlib comment.
- **Sep 5–6** — `e0b3c735f`/`1505b3179`/`642966768` added
  `// store-kinds`, `// store-member-types`, `// store-view`.
- **Sep 14–15** — `// refine` (this session; copied proto's convention).

All commits author "Lars Thomas Denstad" — the repo's agent sessions
commit under that name and trailers were sporadic pre-September
(`384fd31d3` carries a Claude co-author tag). So "who" is: the March
type-mint session invented the pattern; every later use is imitation of
a nearby file, mine included.

## Why it exists

There is no shared comptime registry object transforms can write into —
the program's item stream is the only shared state, and a comment is the
only inert payload that survives to emitted output unchanged. The
pattern buys ordering-independence: a consumer can read a marker for a
transform that already dissolved.

## The honest alternative (found during this audit)

The transform ABI already has `has_ctx` — a transform declaring
`ctx: *CompilerContext` reaches the live compilation in-process, and
`CompilerContext` already threads `tap_registry` (`src/main.zig:2021+`,
the `reporter_inject_fmt` path is the same channel). A typed facet
registry on the context would carry everything the markers carry —
write on transform fire, read by later transforms, ordered by stage —
with zero comment parsing. The cost is `src/` work (registry module +
context field + ABI reachability is already proven by `reporter`).

## Open questions

- RESOLVED for the channel shape: the program tree is the channel —
  no context registry. Markers migrate to typed `Item` variants, one per
  concept (the `host_type_decl` precedent: `kernel.kz` already scans
  `program.items` for typed nodes). `refine` is done (`facet_decl`);
  proto/foreign/store-* remain on the wire.
- `src/type_registry.zig`'s `// foreign` read needs its own fix either
  way — the compiler parsing stdlib comments is an inversion regardless
  of what convention the stdlib uses internally.
- `dead_strip` treats comments as cargo it preserves
  (`hostLineIsCommentCargo`) — a real registry removes that load too.

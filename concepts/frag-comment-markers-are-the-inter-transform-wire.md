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

## Writers — a transform emits `// <ns> …` into `inline_code`

| Marker | Writer | Carries |
|---|---|---|
| `// proto Name: f1: t1, …` | `koru_std/proto.kz:416`, `koru_std/types.kz:166` | compound decl: name + flat field list |
| `// proto-terminal Name: T` | `koru_std/proto.kz:467,518,569,620` | scalar terminal name + host type |
| `// foreign Name: f1, f2, …` | `koru_std/foreign.kz:112` | foreign decl: name + field names |
| `// store-kinds …` | `koru_std/store.new.kz:3133` | store kind arms |
| `// store-member-types …` | `koru_std/store.new.kz:3146` | store member types |
| `// store-view …` | `koru_std/store.view.kz:62` | store view decl |
| `// refine home:Name: f: t & bounds` | `koru_std/refine.k` | refine facet (canonical meet) |

## Readers — a pass parses the comment back

- `koru_std/proto.kz:128,145,292` — `// proto-terminal`, `// proto`
  (its own resolution across dissolution order)
- `koru_std/list.free.kz:184,279` — `// proto` (container synthesis
  finds the element's fields)
- `koru_std/store.kz:538,644` — `// proto`; `:563` `// store-kinds`;
  `:721` `// store-member-types`; `:1183,1316,1341` `// store-view`
- `koru_std/store.new.kz:418` — `// proto-terminal`; `:525` `// proto`
- `koru_std/refine.k:350,389` — `// proto`, `// refine`
- **`src/type_registry.zig:871` — `// foreign`. The compiler core
  parses a comment a stdlib transform emitted. This is the worst edge
  in the inventory: the wire crosses the stdlib→`src/` boundary.**

## Tombstones, not carriers (write-only, nobody scans)

`// std/store: '<name>' created …` (store.new.kz:5882,7048),
`// std/store: watch(...) spliced …` (store.watch.kz:264),
`// std/pump: pump '<n>' created …` (pump.kz:436),
`// branch constructor: …` (main.zig:4528),
`// \`<x>\` is not exported …` (visitor_emitter.zig:4559).
These are debug/tracing output — legal under the ruling.

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

- Do we migrate the existing marker namespaces onto a context registry,
  or is the stdlib-internal wire grandfathered and only *new* carriers
  (refine) required to use the typed channel?
- `src/type_registry.zig`'s `// foreign` read needs its own fix either
  way — the compiler parsing stdlib comments is an inversion regardless
  of what convention the stdlib uses internally.
- `dead_strip` treats comments as cargo it preserves
  (`hostLineIsCommentCargo`) — a real registry removes that load too.

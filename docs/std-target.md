# `std/target` + `std/emitter` — design note

Status: sketched, not implemented. Ruling recorded in
`concepts/frag-a-target-is-a-catalog-entry-not-a-module.md`.
Greenlit 2026-10-24. Companion piece to `compiler:emission`
(the overwritable coordinate tor) — this note covers what that
tor's dispatch arms should eventually consume.

## The claim

A backend target is **declared data plus one shared engine**,
not a per-target module. Today `c_emitter.zig`, `cs_emitter.zig`,
`js_emitter.zig`, and `visitor_emitter.zig` are ~32k lines where
~60% is the same walk (site/continuation traversal, marker
resolution, cell registries, dispatch shape) and ~40% is the part
that is actually about the target. Nothing separates the two, so
each lane re-derives shared semantics privately and drifts — the
N-writers defect already pinned twice at rule granularity.

## The split

```
std/target    — the catalog (declared arms; data)
std/emitter   — the generic walker (target-blind engine)
```

Mirrors `std/realize`: a generic solver over declared rows, with
policy declared separately (`koruos/realize` is one consumer's
rows; `std/target:*` arms are the emission equivalent). The zig
lane is arm `zig`, not a privileged default — `target-of`
resolving to `zig` is the same lookup as resolving to `c`.

`std/emitter` is not a `std/compiler` part: `compiler:emission`
owns when/in-what-order (overwritable); the emitter is the engine
its arms call.

## The catalog row surface (measured against `c_emitter.zig`)

- **identity** — arm name, facet extension (`.kc`), emitted
  artifact (`output_emitted.c`), toolchain (`ccomp
  -fstruct-passing`).
- **types** — Koru type -> spelling, including cell-minting
  schemes: scalars (`i64->long long`, `u8/u6->uint8_t`,
  `string->const char *`...), `*X->struct X *` / pointee rules,
  `[]T -> __koru_slice_<tag>{ptr,len}`, records ->
  `__koru_rec_<shape>`, protos -> nominal `struct <Name>`,
  `i128 -> {lo,hi}` *type-only*, `-> {..}` -> `_res` structs.
- **names** — `mangle(path)`, `cMemberName` (kebab->`_`),
  `cPayloadMember` (`tag`->`__ktag`), `cResTagConst`, cell
  prefixes.
- **builtins** — `@max/@min->__koru_*_ll`, casts, `:.N->%.*f`,
  wrapping ops -> refuse-unless-width.
- **prelude** — includes + helper bodies (`__koru_len_str`,
  `__koru_stdout_write*`, `__koru_streq`, ...).
- **constructs** — dialect pointer: "control spellings come from
  `control.targets.kz`'s `|c` arm" — the facet mechanism may
  already BE this row; open question below.
- **fragment** — the named refusals = the arm's promise boundary:
  concurrency-module axis, resumable `!`, raw host lines, `[N]T`
  fields, destructures, non-`|c` proc bodies, unregistered
  `.assignment` targets, i128 arithmetic.

## What is NOT in the catalog (the walker's vocabulary)

Marker families (`__koru_inline_N`, `__koru_continue[_bare]_N`,
`__koru_len`/`__koru_idx`), `.terminal` tombstones, snapshot
semantics, capture-cell registration, `//@koru:*_scope` preamble
channels, tagged-dispatch shape. Lane-invariant — cs and c already
share them verbatim. The walker is the quotient map AST/~ -> text/~;
catalog rows name each lane's representatives.

## Integration

```
| zig   |> std/compiler:emit-zig(ctx: c2)          (today)
| cs    |> std/compiler:emit-cs-artifact(ctx: c2)

| <arm> |> std/compiler:emit(ctx: c2,
         target: std/target:of(ctx.target))        (after)
```

`emit|zig`/`emit|c`/`emit|cs` are already proc variants in the
`std/build:variants` sense — `--lang=c` is morally
`{ "emit": "c" }`. The arm list in `compiler:emission` is a
hand-rolled variant select; the catalog makes it a row lookup.

## Phasing (each independently revertible)

1. **catalog** — extract per-target tables from the three emitters
   into declared rows; emitters read rows (still `.zig`).
2. **walker** — fold the ~60% shared code into one engine; emitters
   become thin or gone. Refusal messages distinguish "no row" from
   "walker cannot express".
3. **purify** — `std/emitter` Koru-authored; backend reuse keyed on
   `ctx.target` marks (CC's shared-backend ask falls out of marks).

## K3 connection

FlowDialect pairwise congruence runs over declared rows: lanes
agree on the shared fragment iff their overlapping rows denote the
same quotient classes. The catalog is the proof object; the walker
stays trusted machinery. This is the invariant layer the
FlowDialect rung needs to exist before it can be proven over.

## Open questions

- Is `constructs` a pointer to the `|c` template dialect, or
  inlined spellings? `control.targets.kz`'s `for|c`/`if|c` may
  already be the row — then the catalog *indexes* facet dialects
  rather than duplicating them.
- Where do rows live physically: `std/target` facet files
  (`index.kz` + `arms.kz`?), or `koru_std/targets/`?
- `std/target:zig` rows describe what `visitor_emitter` does —
  declared after the fact; the default arm is just the one
  `target-of` returns without `--lang`.

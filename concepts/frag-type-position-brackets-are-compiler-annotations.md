---
type: belief
id: frag-type-position-brackets-are-compiler-annotations
provenance: ruling session with Lars 2026-10-24 — three NEEDS_RULING pins (210_024, 210_039, 310_040) settled by one bracket law
ts: 2026-10-24
---

# A trailing `[]` on a type position is a compiler annotation — opaque, always (belief)

`Type[x]` in a declaration type position is a compiler annotation. Any
content is legal — digits, `!`, regexes — because annotations are opaque
strings the compiler and transforms read, inert at runtime. Stacking is
`Type<phantom>[ann]`: `<>` binds inner to the type name (value-level
obligation, travels with the value), `[]` is outermost (declaration-level
metadata on the occurrence). Extracted into `type_annotations` and stripped
before Zig emission.

The cost accepted with eyes open: `Type[active!]` meant-as-phantom now
produces annotation `active!` and no obligation — the KORU033 bracket guard
is gone from type positions and the failure surfaces downstream instead of
at parse. The trade was taken because the alternative — content-sniffing
the bracket — makes the grammar carry a taxonomy the lane never needed.

Corollary: a call site never repeats the tag. `Source[text]` is declared
once on the parameter; the invocation is `@"path"` or a bare `{ }`. The
`<type>"path"` and `<T>{` echoes were deleted as PARSE001 refusals that
teach the move — an echoed fact is a fact that can disagree.

The ghosts this sweeps: pre-cutover `[state]`-means-phantom fears lived on
as comments and defensive parses (`[celsius]` literals have zero corpus
tenants). Ruling the lane by context — type position vs. binding vs. name —
rather than by content is what made the surface unambiguous. Known and
deliberately deferred: `name[x]` reads as index in write-head lanes
(`store[r].field`) vs. annotation in type lanes — the uniformity question
is parked, possibly forever.

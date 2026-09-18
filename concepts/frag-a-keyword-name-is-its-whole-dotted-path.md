---
type: belief
id: frag-a-keyword-name-is-its-whole-dotted-path
provenance: 395_014 — `assert.eq`/`assert.contains` declared-but-unemittable; found while filling std/testing for domain cells
ts: 2026-09-18
---

# A keyword's name is its whole dotted path; every segment-slice of it is a different name (belief)

`assert.eq` could not fire as a transform until three singleton assumptions
fell, each a place the machinery had sliced the name or the params down to
one and silently dropped the rest:

1. **Registration took the last segment.** `[keyword]` events entered the
   registry under `segments[len-1]` — `assert.eq` was only findable as `eq`.
   The dotted path itself is also a keyword name and must be registered:
   `assert.eq`, whole.
2. **Resolution early-returned on multi-segment paths.**
   `if (path.segments.len != 1) return;` meant `assert.eq(...)` never
   acquired a module qualifier in cloned test bodies — and the transform
   dispatcher's qualified-only gate closed. The invocation survived to
   emission as a raw `.handler(.{ .@"1" = 1 })` call: compile-broken,
   and diagnosed nowhere near the actual miss.
3. **Arg extraction assumed one Expression param.** The transform
   call-site kept a single `expression_field_name` and one
   `extractExprFromArgs` — the second `Expression` param of `assert.eq`
   was left uninitialized in the emitted `handler.Input`. Extraction is
   per-param: named arg wins, else positional index among args.
   Sibling slice: `bindImplicitExpressionArg` looked the event up by
   `segments[0]` and bound `assert.eq(1,1)`'s first arg to `assert`'s
   `expr` param — the wrong decl entirely. The lookup name is the joined
   path, always.

The pattern is `frag-a-type-word-prefix-must-match-a-final-segment`'s twin:
where that one corrupted names by matching too loosely (substring for
segment), this one orphaned them by matching too little (a slice for the
whole). **A name is the whole dotted path** — at registration, at
resolution, at decl lookup. Any helper that takes `segments[0]` or
`segments[len-1]` and calls it "the name" is a latent bug against the next
multi-segment event.

Open: optional `?Expression` params in multi-expression handlers still
route through the single-name `expression_field_name` path — a mixed
required+optional signature is unmeasured.

Related: [[frag-a-type-word-prefix-must-match-a-final-segment]],
[[frag-every-name-writing-site-must-mangle]]

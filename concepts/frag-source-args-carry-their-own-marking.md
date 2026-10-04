---
type: belief
id: frag-source-args-carry-their-own-marking
provenance: stack-driven emitter defect 2026-10-04 — a subflow impl calling
  `capture { v: 40[i64] }` emitted `.source = v: 40[i64]` raw into the Zig
  struct literal, on both the emitArgs decl-miss path and the subflow-head
  call writer. Pinned by 310_136 / 310_137.
ts: 2026-10-04
tags: [koru, emitter, source, transforms, comptime]
---

# A Source arg's marking is on the arg, not the callee decl (belief)

The parser marks a Source-typed argument at capture: `arg.source_value` is
set, and `arg.value` holds the captured *text*. Every emission path that
writes a call's input struct must serialize that arg as the
`__koru_ast.Source{ .text = ..., .scope = ..., .phantom_type = null }`
literal — one serializer (`emitSourceValue`) — never `arg.value` raw.

The defect class this closes: emitters that asked "does the callee's decl
say this field is_source?" instead of "did the parser capture source here?"
Two sites did exactly that. `emitArgs` fell back to raw `arg.value` when its
event-decl lookup missed — and the lookup legitimately misses for callees
that are not plain event decls (transforms like `capture`/`captured`
resolve through a different table). The subflow-head call writer in
`visitor_emitter` had no source branch at all. Both produced Koru syntax
spliced into a Zig field — `.source = v: 40[i64]` — which can only ever be
a backend rejection.

The rule follows: decl lookup is a *hint* for param-name resolution; the
type-of-the-arg is already on the arg. An emitter that routes by decl
alone will splice raw text wherever the decl is unresolvable — and the set
of unresolvable decls grows with every callee kind that isn't a plain
event (transforms today, whatever comes next).

## The walker's boundary is the same wall

`evalArgs` in the comptime walker hit the identical shape from the other
side: `arg.value` for a Source arg is captured text, not an expression, so
`evalText` mis-parsed it as TrailingGarbage. The named wall — "Source
params belong to transforms, which run at elaboration, not to walkable
calls" — is `flowIsFoldable`'s rule ("Source params are transform/build
machinery, never foldable") stated for the walk path. A Source capture
reaching a call evaluator means a transform was never applied at
elaboration — the honest refusal names that boundary rather than
mis-parsing the payload.

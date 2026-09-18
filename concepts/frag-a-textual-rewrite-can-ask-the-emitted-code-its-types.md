---
type: belief
id: frag-a-textual-rewrite-can-ask-the-emitted-code-its-types
provenance: surfaced by WO-005 (intranquil-domain) — `?string == "lit"` lowered to `mem.eql` on the optional, not the payload
ts: 2026-09-06
---

# A textual rewrite can ask the emitted code its types (belief)

`rewriteZigExpr` (codegen_utils.zig) rewrites Koru operator surface into Zig
with **no type oracle** — it sees operand text, not types. For a long time
that meant the rewrite could only handle operands whose types it could
assume; `identifier == identifier` is still refused for exactly that reason
("needs a type oracle", pinned at 320_140's cluster).

That assumption is too strong. The emitted Zig is itself a comptime
program: `if (@typeInfo(@TypeOf(x)) == .optional) x.? else x` selects per
operand *in the generated code*, and the untaken branch is never analyzed.
So a rewrite that cannot see types can emit a presence- and shape-aware
block that lets the backend's own type system answer the question — the
oracle the rewrite lacks lives one stage later, for free.

The shape that fell out for `?string == "lit"`:

- bind both operands once (`const __koru_l = …; const __koru_r = …;`),
- compute presence bits per side (`x == null` if optional else `false`),
- `(__koru_ln == __koru_rn)` — `null==null` is true, `null==value` false
  without touching the payload,
- `__koru_ln or mem.eql(...)` — only unwrap when present,
- comptime dispatch means the non-optional case folds back to plain
  `mem.eql` — the common path costs nothing.

**When this applies:** any textual lowering blocked on "we don't know the
operand's type" — optional unwrap, union tag, integer width. Emit the
comptime question instead of threading a type table through the rewriter.

**Open:** presence-semantics for `null != null` and optional-vs-optional
comparisons are pinned at 320_147 but the *general* doctrine (which
operators deserve presence dispatch) is not — `!=` got it because it is
`!(==)`, not because anyone ruled on optional inequality as a surface.

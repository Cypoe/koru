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

**Refined 2026-09-06 (same session, second half of the defect):** the
doctrine extends from *presence* dispatch to *type* dispatch. `h1 == h2`
(two identifiers, no literal) used to fall through the rewrite untouched
and emit a bare `==` — uncompilable Zig when both were strings. The fix
keeps the trigger textual (no literal operand on either side, because
`const r = .audio` / `= null` / `= 0` would strand the literal without a
result type) and moves the whole decision into the emitted block: unwrap
optionals to payload types, test "is a u8 string/slice/array" per side,
take presence-aware `mem.eql` when both match, plain `==` otherwise. One
emission shape now covers `str==str`, `?str==str`, `int==int`, `enum==enum`
— the comptime fold makes each specialization free. The cost is emitted-
code size, not correctness: a non-string pair never analyzes the mem.eql
arm.

**Open:** which *other* operators deserve payload dispatch is still
unruled — `!=` has it only because it is `!(==)`. Ordering (`<`/`>`) on
strings (`std.mem.order`) is the next natural candidate when a consumer
asks.

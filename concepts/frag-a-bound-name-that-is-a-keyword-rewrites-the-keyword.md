---
type: belief
id: frag-a-bound-name-that-is-a-keyword-rewrites-the-keyword
provenance: the intranquil-domain WO-012 cell (2026-09) declared `variant.promote { var: *Variant<live> }` and the emitted body read `@"var" n: usize = 0;` — a Zig syntax error at a declaration site the author never wrote.
ts: 2026-09-22
---

# When a bound name IS a Zig keyword, the rewrite cannot tell the keyword from the reference

`escapeBoundNames`/`replaceIdentifier` rewrites every word-boundary
occurrence of a bound name inside spliced text to its canonical spelling.
That is correct for references — `var` the param must emit `@"var"`. But
the same byte sequence at DECLARATION position — `var n: usize = 0;` —
is the Zig keyword, and rewriting it produces `@"var" n: usize = 0;`, an
undeclared-identifier-shaped syntax error. The rewrite is positional-
blind: it cannot distinguish `var`-the-keyword from `var`-the-reference
because Zig itself only separates them by grammatical position.

The escape hatch exists and is wrong to need: hoisting the body into a
module-scope fn (which never substitutes param names) is idiomatic in
the corpus — the cell used it — but the defect stands: a legal Koru
param name makes a legal Zig keyword unusable in its own event's body.
The fix direction is a rewrite that knows Zig's keyword positions, or
canonicalizing the binding so author text never collides. Pinned red:
`230_021_keyword_param_rewrites_body_keyword`.

Related:
[[frag-every-name-writing-site-must-mangle]] — the parent invariant; this
is the case where the ONE canonical spelling is itself ambiguous, so
mangling alone cannot resolve it.
[[frag-the-safe-koru-identifier-surface-is-smaller-than-the-language-says]]
— the author's side of the same wall.

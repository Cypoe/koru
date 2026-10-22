---
type: belief
id: frag-unspaced-minus-is-a-name-char-the-author-cannot-see
provenance: 910_LANGUAGE_SHOOTOUT/nbody kernel_fused.kz silently stopped compiling — bisected 2026-10-22 to `c[i].x-c[j].x` (unspaced) in the energy loop's captured update; pinned 390_129
ts: 2026-10-22
tags: [koru, lexer, grammar, identifiers, kebab, ambiguity, emission]
---

# Unspaced `-` is a name character — uniformly — and the compiler now teaches the spaced spelling (belief)

Kebab is the house spelling for names (`life-step`, `pitch-offset`), which
makes `-` a legal identifier glyph. **Ruling (Lars, 2026-10-22): `-` stays
a name character, uniformly, in every grammar.** Unspaced `a-b` is always
one name token. The corpus already voted: spaced ` - ` appears ~1400
times in tests while unspaced subtraction in expression position is
essentially zero — unspaced `-` is a name glyph, spaced `-` is the
operator.

The trap was never the rule — it was that the rule was (a) invisible: a
silently-folded name produced a Zig error downstream, never a Koru
diagnostic; and (b) applied inconsistently: `a-b` in a captured update
folded to identifier `x_c`, while `a-b` in bare-return passed through
verbatim and Zig read subtraction — right answer, wrong derivation.

## What the measurement actually showed (revised)

The bisect that produced this fragment blamed "two grammars." Wrong
layer. `-` was uniformly a name char already; the asymmetry lived in the
emission's binding set. Event input fields destructured to mangled Zig
consts (`const a_b = __koru_event_input.a_b`) but were never registered
in `zig_scope_bindings`, so `escapeBoundNames` could not rewrite
references — kebab params were *unreferenceable* in impl bodies
(`return a-b` emitted verbatim; `if(x-y > 0)` the same). Two defects,
not a grammar fork:

1. **Emission** — `escapeBoundNames` now also scans
   `ctx.impl_event_decl.input.fields` (every handler ctx already carries
   the impl tor, so one scan covers bare return, args, guards,
   assignments, produce values). Immediate impls and the module-subset
   paths seed the decl/bindings the same way (230_027).
2. **Diagnostic** — KORU181 in flow_checker: an unspaced `-`-joined token
   that binds nothing while every `-`-segment resolves is near-certainly
   subtraction — "'q-b' reads as one name, not subtraction — write 'q - b'"
   (220_052). The check lives in name resolution, not the lexer, because
   only there do "both halves bound" and "whole name unbound" mean
   anything. It scans args, produce values, assignment fields, conditions,
   and control-node expression text.

## What follows

- **Write subtraction spaced.** `a - b` cannot be an identifier; the
  spelling is unambiguous under the uniform ruling.
- **Resolve-by-scope was rejected.** "`a-b` is a name if bound, else
  subtraction" is non-compositional — adding a binding would silently
  reinterpret existing source. Semantics must not depend on what is in
  scope at parse time.
- **Residual silent case:** a *bound* `a-b` where the author meant
  `a - b` still folds to the name — uniform, rare, same class as
  COBOL's answer. Accepted as the cost of keeping kebab on the
  identifier surface.
- **Member-position `.x-c`** (the nbody trap itself) still resolves as
  field `x_c` with no Koru-side diagnostic — a member name is type-
  resolved, not scope-resolved, so flow_checker's scan cannot see it.
  Naming the gap honestly; a type-aware check would be the fix.

Related:
[[frag-every-name-writing-site-must-mangle]] — the same kebab glyph seen
from the write side; this belief now covers the read side: reference
sites spell through the same mangling, sourced from the impl decl when
the scope set was never told.
[[frag-the-safe-koru-identifier-surface-is-smaller-than-the-language-says]] —
the other direction of the contract gap: names legal in Koru that are
illegal downstream. The kebab-param defect was exactly this class — a
declared `a-b` the emitted program could not reference.

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
   and control-node expression text — including named-branch bodies under
   conditional/foreach/switch (220_053 args, 220_054 branch bodies).

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
  identifier surface, and pinned as green behavior: 230_028 binds
  `a-b`, `a`, `b` together and shows `a-b` yields the name while
  `a - b` subtracts.
- **Member-position `.x-c`** (the nbody trap itself) is now diagnosed —
  KORU182. Member names resolve against a type, not the scope map, so the
  check needed a field-set oracle it didn't have. flow_checker now
  enumerates statically-known receivers: impl input params (inline
  `{ x: i64 }` record text, named types via `host_type_decl` /
  `kernel:shape`), `| branch` payload bindings, and kernel
  `| computed` / `| kernel` bindings inside `init(T)`/`pairwise(T)`
  flows — `c[i].x-c` resolves `c` → the shape's fields through `[]`
  peeling. When `x-c` is no field but `x` is and the rest resolve as
  names, it teaches `x - c` (230_029 frontend pin, 390_130 kernel
  receiver). Two conservative declines: a *declared* kebab field
  (`p.x-c` where `x-c` is real → legal, run-pinned in 230_030 — emits
  `p.x_c` correctly on named bindings) and receivers whose types don't
  enumerate (scalars, host types, `.len`-style builtins — the host's
  field check keeps those). Member chains descend (`a.b[i].x-c`).
- **Immediate impls were a second hole.** `use -> p.x-c` never entered
  the scan at all — `checkImplMatchesDecl` validated shape, not names.
  It now runs the same token scan over produce text with the decl's
  input fields as scope — KORU181 and KORU182 both reach `->` bodies.
- **Arg-position record literals reach Zig unlowered** — found while
  probing member position: `use(p: { x: 10 })` emits `{ x: 10 }`
  verbatim (not kebab-specific; bare-return literals lower fine, the
  inline-arg path skips it). Whether arg literals are intended grammar
  is open — legal → lower, illegal → frontend refusal; either way not
  a raw host error. Pinned in 230_031.
- **Transform-captured args are a carrier gap.** `if`/`each`/etc arrive
  as invocations whose condition arg is captured `expression_value`;
  the scan does not open captured args, so `if(q-b > 0)` passes `q-b`
  through verbatim and Zig reads subtraction — right answer, wrong
  derivation again, now on the *scan* side. The same wall stands between
  KORU182 and the nbody's actual carrier — `captured { energy: acc.energy
  + c[0].x-c[j].x }` is `source_value`, never scanned — so the trap that
  started all of this stays silent inside `captured`/`capture` bodies
  even though the member check can now resolve `c` → the kernel shape.
  Pinned green-and-documented in 220_055, explicitly framed as the
  tripwire: opening captured args flips it red until repinned as a
  MUST_ERROR twin of 220_054.

Related:
[[frag-every-name-writing-site-must-mangle]] — the same kebab glyph seen
from the write side; this belief now covers the read side: reference
sites spell through the same mangling, sourced from the impl decl when
the scope set was never told.
[[frag-the-safe-koru-identifier-surface-is-smaller-than-the-language-says]] —
the other direction of the contract gap: names legal in Koru that are
illegal downstream. The kebab-param defect was exactly this class — a
declared `a-b` the emitted program could not reference.

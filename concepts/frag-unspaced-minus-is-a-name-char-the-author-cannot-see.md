---
type: belief
id: frag-unspaced-minus-is-a-name-char-the-author-cannot-see
provenance: 910_LANGUAGE_SHOOTOUT/nbody kernel_fused.kz silently stopped compiling — bisected 2026-10-22 to `c[i].x-c[j].x` (unspaced) in the energy loop's captured update; pinned 390_129
ts: 2026-10-22
tags: [koru, lexer, grammar, identifiers, kebab, ambiguity, emission]
---

# Unspaced `-` is a name character in expression grammars — subtraction must be written spaced, and nothing says so (belief)

Kebab is the house spelling for names (`life-step`, `pitch-offset`), which
makes `-` a legal identifier glyph. That choice has a hidden cost: **every
unspaced `a-b` in an expression is an ambiguity** — identifier `a-b` or
subtraction `a - b` — and the resolution is not a language rule, it is a
per-grammar accident.

Measured 2026-10-22, koruc @ dc2acc0aa:

- In a `captured` update expression, `c[0].x-c[j].x` lexes `x-c` as the
  identifier `x_c`, emits `c[0].x_c[j].x`, and Zig refuses with "no field
  named 'x_c'" — a diagnostic quoting code the author never wrote.
- In bare-return position, `a-b` passes through verbatim and Zig happens to
  read it as subtraction — right answer, wrong derivation.
- In a `.kz` showcase that compiled clean on 2026-09-18, `c[i].x-c[j].x`
  meant subtraction. The grammar moved under it; the error surfaced only as
  a backend refusal in an unexercised directory.

Two grammars, two resolutions, both silent. If the language intends `-` to
be greedy for names, the bare-return passthrough is the bug. If it intends
subtraction, the captured grammar is the bug. Either way the *asymmetry* is
the defect: an author cannot predict which reading they will get, and the
failure mode is a Zig error in generated code, not a Koru diagnostic.

## What follows

- **Write subtraction spaced.** `a - b` cannot be an identifier; the
  spelling is unambiguous under every resolution the language could choose.
  The showcase fix was exactly this — three spaces, no semantic change.
- **The boundary needs a ruling, not a convention.** Options measured:
  keep `-` as a name char and reject/warn on unspaced subtraction-shaped
  tokens in expression grammars; or make `-` an operator always and take
  kebab names off the identifier surface. Both are coherent. What is not
  coherent is each grammar choosing separately.
- **Corpus grep does not cover this.** The trap fired only at emit time —
  `--check`-class passes see a well-formed name. A pin exists
  (390_129: spaced field-subtraction over a `computed` kernel slice inside
  for+each) but the *trap* itself has no diagnostic. An unnumbered
  showcase dir was the only corpus site carrying the spelling, which is
  how it rotted unobserved.

Related:
[[frag-every-name-writing-site-must-mangle]] — the same kebab glyph seen
from the write side: declared names need mangling into Zig; this is the
read side, where an author's `-` is claimed by the identifier surface.
[[frag-the-safe-koru-identifier-surface-is-smaller-than-the-language-says]] —
the other direction of the same contract gap: names legal in Koru that are
illegal downstream. Here the token is legal in Koru *and* legal downstream —
as a different program than the author wrote.

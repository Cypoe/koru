---
type: belief
id: frag-dimension-algebra-is-model-scoped
provenance: session 2026-09-14 — ruled in conversation: unit algebra lives inside a model's sealed vocabulary, not in the language
ts: 2026-09-14
tags: [koru, phantom, units, signal]
---

# Dimension algebra is model-scoped, not language-wide — phantom labels are open vocabulary by design (belief)

Phantom labels on primitives (`f64<percent>`, `i32<meter/second>`,
`[]const u8<net:tainted!>`) are deliberately **opaque strings**: the checker
tracks and matches them, but `meter/second` is not derived from `meter` and
`second` — the author declares the dimensional transition in the event
signature. That is a design choice to keep, not a gap to close.

Rejected alternative, and why: a general units-of-measure feature in the
language (the F#/Frink route) must serve every domain's algebra — SI,
tokens/s, currency pairs, calendar math — and none of them well, forever.
But a signal *model* is a **sealed world**: its unit vocabulary is closed
by declaration and its legal derivations are enumerable (the transfer
table). "Does this model's arithmetic stay inside its declared dimension
grammar" is answerable precisely because the scope is closed; "do all Koru
programs' units typecheck" is a research project. Algebra-checking is
tractable only at model scope.

The honest cut:

- **Language (phantom):** open-vocabulary labels, *flow* enforcement — a
  mismatched label refuses to compile. The label is the mechanism.
- **Module (signal:units):** closed vocabulary + derivation rules — the
  *algebra* enforcement. The registry knows `tokens`, `s`, `percent`, `1`
  and that `tokens/s` is a derivable dimension.

What the registry buys that open labels cannot: a typo'd label
(`f64<pecrent>`) silently mints a new dimension today and fails only as
"no tracked phantom" — never as "unknown unit." A closed vocabulary makes
the vocabulary itself checkable. The language provides the label; the
module provides the meaning.

---
type: belief
id: frag-an-override-is-its-home-not-its-qualifier
provenance: compiler-override demo session 2026-09-10 — module-resident coordinator override silently ignored; fixed with home-aware override walks, pinned by 430_014
ts: 2026-09-10
tags: [koru, overrides, abstract-impl, canonicalization, module-qualifier]
---

# An override is its home, not its qualifier (belief)

Whether an implementation of an abstract tor is the OVERRIDE or that
module's own default is a fact about CUSTODY — which module the impl
lives in — not about the module qualifier it spells. Canonicalization
stamps the enclosing module onto an unqualified impl, so after that
pass a module's own default and a foreign override carry the SAME
qualifier; a pairing predicate keyed on the qualifier alone cannot
tell them apart. At entry top level the two readings coincide — the
entry is not a module, so any impl naming another module's tor is
foreign by definition — which is why the flat top-level scans worked
for years, and why widening them without the home check would have
claimed every module-internal default as its own event's override and
emitted the default pipeline as the handler.

This is the pairing-side twin of [[frag-an-imported-transform-fires-only-on-its-own-home]] (dispatch), and the custody dual of the identity-exclusion doctrine in [[frag-a-pass-that-can-remove-the-last-implementation-must-answer-to-the-check-that-required-one]] (pointer identity, not a better predicate — here the same instinct applied to WHERE an impl lives). The pins: 430_014 (the coordinator) and 430_015 (a user-library runtime abstract overridden from a second module); 430_001 is the entry-top-level control that must not regress.

What would correct this: a canonicalization that stops stamping the
enclosing module onto unqualified impls (the qualifier would
discriminate again and the home check becomes redundant), or a ruling
that an abstract may be overridden by its own module on purpose (then
home-exclusion is wrong for that case and the predicate needs a
marker, not a place).

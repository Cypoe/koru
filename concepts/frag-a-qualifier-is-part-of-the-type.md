---
type: belief
id: frag-a-qualifier-is-part-of-the-type
provenance: phrygian-outfit arc 2026-10-09 — phantom-contract ruling, Lars-settled
ts: 2026-10-09
tags: [koru, phantom, obligations, semantics]
---

# A qualifier is part of the type — and a wildcard cannot promise settlement

Two halves of one ruling, ruled together because they are the same honesty:

**The qualifier is type identity.** `string` and `string<open>` are different
types. An unqualified parameter accepts only unqualified values — a qualified
argument into an unqualified slot is a type mismatch, not a satisfied absence
of requirements. Sites that genuinely take anything spell it: `<*>` is the
explicit any-qualification borrow.

**Discharge is a settlement contract, not a type match.** `<!state>` on a
parameter is a promise to perform the minting module's cleanup semantics for
the NAMED contract `state`. `<!*>` claims to settle any obligation from any
module without knowing that module's cleanup semantics — the promise cannot
be made honestly, so the spelling is refused at parse (KORU033), for every
shape: `<!*>`, `<!module:*>`, `<module:!*>`, and wildcard members inside
unions. Refusal must be loud — never silently reinterpreted as a borrow,
which is the failure the string-level helpers guard against.

The line the ruling draws: wildcard BORROW is honest (it asks nothing of the
callee); wildcard CONSUME is not (it claims a duty it cannot name). Cross-module
discharge stays legal exactly when the contract is named — `<!app/fs:opened>`
compiles; `<!*>` does not.

Pinned: `330_137_wildcard_consume_refused`.

What would correct this: a concrete program that needs wildcard settle — a
genuinely parametric disposer whose cleanup semantics are uniform across
minting modules — would weaken "must name the contract" to "must name the
contract OR declare uniform semantics." No such program exists today.

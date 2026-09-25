---
type: belief
id: frag-a-declared-label-name-is-one-a-jump-can-spell
provenance: tightening-016 probe of label-declaration argument records — `@done(r: {a: 1, a: 2})` compiled clean, minting a label no jump can name
ts: 2026-10-11
tags: [koru, labels, parser, diagnostics, declaration-vs-use]
---

# A declared label name must be one a jump can spell; argument text on a declaration is a malformed name, not a payload (belief)

Label declarations — `~@name`, `~#name`, `~#name event(...)`, and the `.k`
spelling `@name` — used to take the rest of the line as the name verbatim.
`@done(r: {a: 1, a: 2})` parsed and compiled clean, registering a label
literally named `done(r: {a: 1, a: 2})`. No `@name` jump can spell that —
the jump's `extractLabel` takes identifier characters only — so the
declaration minted a label unreachable by construction.

Worse, the misattribution was built in: a following `@done` jump (with its
own, legal, argument list) then failed as "unknown label" — the *jump* took
the blame for the *declaration's* fault, the inversion
frag-a-reproducible-failure-localises-the-symptom-not-the-defect warns
about: the error surfaced where the invariant was checked, not where it was
broken.

## The rule

A label declaration's name is an identifier — the same grammar the jump
spelling accepts. Anything else after the sigil is malformed syntax, refused
at the declaration with `PARSE003`, before any jump can be blamed for it.
Arguments belong on the jump (`|> @done(r: 1)`), never on the anchor;
the declaration is not a payload-bearing site. This is the declaration-side
sibling of the rule that a jump's argument must be a spelled `name: value`
pair — both ends now refuse the other's syntax.

## Open

- The same "declared name must be spellable at every use site" question
  applies wherever a declaration takes a free-text tail; labels were the
  measured hole, but the enumeration that found them (a jump can only spell
  identifiers) generalises — event names, tor names, and the `#name` on
  pre-invocation anchors all take name text from a line tail and are worth
  the same census.

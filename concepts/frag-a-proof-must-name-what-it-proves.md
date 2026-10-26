---
type: belief
id: frag-a-proof-must-name-what-it-proves
provenance: the `__koru_gi_` trusted-write prefix over-trusting a sweep/for
cursor when the write landed on a different grid — caught while wiring
`std/grid:for`, fixed by minting `__koru_gi_<grid>_L<line>`
ts: 2026-10-21
---

# A proof must name what it proves (belief)

`sweep` minted trusted cursors as `__koru_gi_L<line>` — a name that attested
"a grid-owned loop checked this index" and no more. `grid:stored` trusted any
write whose index text carried the prefix. Both were locally correct; the
composition was not: a cursor minted by a loop proven against `cells` could
address a write to `dst` unchecked, because the attestation carried
provenance (who minted it) but not scope (what was proven).

A proof that does not name its subject is forged by distance. The farther
the attestation travels from the check — minted in one transform, honored in
another, matched as raw text — the more the name itself must carry. The fix
was not a registry or a side table: the mint spells the grid
(`__koru_gi_cells_L7`), and honoring it means parsing the name back. The
same failure class is anywhere a marker says "trusted" without "for what":
a guard keyed on zero is off for whoever gets zero
([[frag-a-guard-keyed-on-zero-is-off-for-whoever-gets-zero]]) — same shape,
a check whose authority outlived its scope.

Open question: the mint is text and the match is textual, so a second
binding that spells the same name (a shadowing arm — `! each i` inside
`! each i` — is refused by the shadow rule, but a user could not mint the
name because `__koru_gi_` is reserved... verify that reservation actually
holds for user identifiers) inherits the proof. The contract is only as
strong as the namespace's exclusivity.

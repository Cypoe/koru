---
type: belief
id: frag-an-auto-registered-signal-mints-as-not-a-belief
provenance: koru session 2026-09-26 — ecology check of the discipline machinery; the orphan drain measured 50/125 stubs and found the membrane:false minting leak
ts: 2026-09-26
tags: [koru, membrane, signals, world-model, discipline-machinery]
---

# An auto-registered signal mints as not-a-belief

A commit that declares a `Signal:` name the registry does not know mints an
orphan stub — `membrane: false`, `note: refine me`. That default is load-bearing
and wrong-shaped: `membrane: false` means the commit-msg interlock (belief-class
signal ⇒ concept staged in the same commit) never fires on the name, so a new
vocabulary word for belief work bypasses the garden entirely. `Signal: evolve`,
`Signal: corrected`, `Signal: belief-change` were all minted this way and all
ran un-gated until a drain rewrote them.

Measured 2026-09-26: 50 of 125 signal files were orphans — 40% of the declared
vocabulary — and the heavily-used ones were mostly belief-class in practice
(`belief` 77 declarations, 37 staged concepts anyway; `belief-change` 33/27;
`corrected`-class names sliding past `correction`'s `membrane: true`).

## The ruling

Register-on-miss stays (it is what makes the vocabulary self-growing), but the
drain established two conventions that hold the line:

- **Promotion by usage.** A name history actually uses (`gap` 175, `defect` 68)
  earns a real definition in place — the canonical is the spelling that won,
  not the one refined first.
- **Tombstone, not delete.** A semantic duplicate keeps its file — the name
  stays defined so register-on-miss cannot re-mint it — with the note pointing
  at the canonical and `membrane` mirroring the canonical's flag, so a
  belief-class alias still hits the interlock.

## Open question

Whether minting should default `membrane: true` (every new name forces the
interlock once — aggressive, catches typos as gardening obligations) or the
tombstone convention suffices. Parked as a lead in
`challenges/027_the_auditors_audit.md`.

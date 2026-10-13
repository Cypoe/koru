---
type: belief
id: frag-a-neologism-is-licensed-by-registration-not-ruling
provenance: concordance-matrix seeding, 2026-10-12 — the verify-path arc had minted a dozen terms (custody-edge, held, issued, obligation-synthesis, unauthorable) with no register anywhere; GLM's audit noted refusal-matrix + obligation-matrix already exist and the deslop baseline already pins `spellings=`, so the missing wall was the third axis: provenance
ts: 2026-10-12
---

# A neologism is licensed by registration, not by ruling (belief)

The discipline question about invented vocabulary is not *"is this coinage
justified?"* — it is *"is this coinage registered?"* The two have opposite
urgency and the repo already separates them.

A ruling — canon-alias vs. warranted neologism — may wait. Deferred decisions
resolve themselves: most coinages look obviously defensible at mint time and
get honestly assessed only once the thing they name has grown edges worth
naming. `move` sat in the callsite-proofs draft for a week before the custody
implementation discovered no move settle path existed — the term would have
been ruled *warranted* at mint and *dead* a week later. Premature ruling is
harmless only if it was never required to mean anything.

But the registration cannot wait, because registration is what makes a term
*visible at all*. `docs/concordance-matrix.md` rows answer two questions a
diff never asks: does canon already have this word (`tor` shadows
outcome-typed function, `auto-discharge` shadows drop elaboration), and who
minted the spelling (which is provenance, not blame — the same fields the
frags already carry). A term that lands unregistered is invisible to exactly
the audit that would question it.

This is the third matrix because the other two already occupy their axes:
refusal-matrix projects *behavior the contracts refuse*, obligation-matrix
projects *behavior the obligations produce*, concordance registers *the words
themselves*. And the deslop `spellings=` baseline already counts vocabulary
growth — growth is caught; what was missing is that a new spelling had no
obligation to *say what it is*. The wall was watching drift; now it watches
provenance.

The falsifiable edge: if most rows settle as `canon-alias` over time, the
language's invented vocabulary is mostly honest and the matrix is cheap
hygiene. If `unplaced` rows accumulate without converging, the registration
gate is recording provenance without disciplining coinage — the registry is
real and the license is theater, and that is a different doc's problem.

Related: [[frag-synthesis-is-licensed-by-how-little-it-invents]] — the sibling
license on the synthesis axis; [[frag-the-vocabulary-wall-guards-drift-not-defiance]]
— the first vocabulary wall, guarding the wrong threat on the other axis.


## Evolved 2026-10-12: registration caught three kinds of drift the same day

Within a day of the first seeding, acting on the matrix produced three
corrections the unregistered flow would never have surfaced. `move` ruled
dead — the settle paths it named shipped as `held`/`issued`, so the draft's
vocabulary had quietly diverged from the implementation and nobody had
noticed. `attendant` removed — a row minted from session memory with zero
tree hits; the registry caught a term that never existed in the tree at
all, which is the audit's cheapest possible win. And `K3` demoted from
filesystem name to doc-layer vocabulary (`verify/k3` → `verify/witness`,
`K3_WITNESS` → `WITNESS_CHECK`, `KORU_K3` → `KORU_WITNESS`): session
ordinals fossilizing into filenames is exactly the drift this matrix
exists to catch, and it was already days deep — in six test markers, two
scripts, an env var, and a Lean namespace.

The falsifiable edge sharpens: a registry that catches a dead term, an
invented term, and a fossilized session name in its first pass is doing
work. One that merely recorded would not have.

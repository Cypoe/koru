---
type: belief
id: frag-a-gate-profile-is-a-selection-not-a-pipeline
provenance: designed in the 2026-09-29 session (Lars + Devin) — the std/gate
  shape settled against explain.kz's [explainer] gather and gate.py's ported
  semantics; landed as koru_std/gate.kz + 220_049 in the same commit
ts: 2026-09-29
---

# A gate profile is a named selection over dispersed rules, not a pipeline pass (belief)

A gate is not something a compilation runs. It is a *name* a tool call can be
aimed at: `koruc <file> gate dev` asks the program "who holds you to `dev`
standards?" — and the answer is assembled at ask-time from rule declarations
scattered through the module closure, tagged into the profile. Membership is
dispersed (the row lives next to the code it constrains); the profile block
itself carries only the name and the default stance.

This is the arity distinction that separates it from `explain`: an explainer is
one-to-one — it reports how a library interpreted *this* program, one answer
per module. A gate is one-to-many — the same module answers differently under
`dev` vs `aerospace`. That arity forces the profile to be a *declared object*
(`std/gate:profile`), not a tag convention: `koruc file gates` can only list
what exists if existence is a declaration, and a sanctioned profile becomes
shippable — it rides the mint's loaded-file closure, so `use(aerospace-koru)`
inherits the org's gate surface inside the pinned artifact.

## What was deliberately not built

- **No profile inheritance.** proto's `Name <: Parent + Parent` field-union
  machinery is 473 lines of resolution for a content-merging problem a gate
  does not have — a profile's block is empty of content; its members live
  elsewhere. "aerospace is dev plus more" is expressed per-row
  (`tags: ["dev","aerospace"]`), not by a second resolution order. If a
  consumer hurts for composition, it lands as tag-set inclusion — twenty
  lines, not a resolver.
- **No pipeline embedding.** A gate never fires as a compilation step — that
  would be hostile to development and is exactly the failure mode the
  tool-call shape exists to avoid. The declaration is committed; the decision
  to run stays an invocation.
- **No depth parameter.** Commands reach as far as their `depends on` closure
  reaches — depth is computed from demand, never declared as a stage enum.

## The runner in-language

`std/gate`'s command ports gate.py's semantics onto the AST directly — the
text-protocol seam (a Python process regexing `std.debug.print` output) is
gone for the rows it covers. Deterministic `check:` rows exec from the
profile-declaring directory; `odds-N` rolls `sha256(name ++ \0 ++ staged
diff)` byte-for-byte as before; `<profile>-local` scopes to the row's own
file's staged diff; `repo-X` scopes to a consumer repo. Judgment-class rows
delegate: the profile's `judge` field names the verdict binary — argv is
(rule, staged state), the first stdout line is the verdict
(VIOLATION / CLEAN / anything else reads UNJUDGED), `judge_src` names the
source a stale binary rebuilds from through `koruc build`, the key
provisions from `~/.config/koru/openrouter.env` when the env lacks it, and
the ~96KB state bound is kept. A profile with no `judge` UNJUDGEs every
judged row with the cause named — delegation is a declared property of the
profile, not an ambient capability. UNJUDGED under an enforcing profile
blocks.

## Open

- The in-language check *tor* — a `[gate]`-annotated member returning a
  structured verdict + evidence rows (the ExplainReport shape with `at`
  witness hashes) — is designed but not built. `check:` strings are the
  tolerated wart until then; when they exist, judged rows get a prepared
  evidence packet instead of a raw diff, shrinking the judge's input to the
  irreducibly judgmental part.
- Whether `std/invariants` stays the only row-declaration surface or gates
  get their own row tor is unsettled; v1 deliberately reuses it — a rule is
  a rule, and the profile question is orthogonal to the rule's disposition.

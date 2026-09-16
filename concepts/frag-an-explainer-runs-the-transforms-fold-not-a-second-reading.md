---
type: belief
id: frag-an-explainer-runs-the-transforms-fold-not-a-second-reading
provenance: koru session 2026-09-16 — explain landed for real: spine repair + std/refine and std/list explainers; 310_064, 671_018, 671_019 pin the pattern
ts: 2026-09-16
tags: [koru, explain, transforms, comptime, legibility, architecture]
---

# An explainer runs the transform's fold, not a second reading of the program

`std/explain` gives every module a report surface: an `[explainer]` tor
takes `*const std/compiler:Program` and returns a typed `ExplainReport`
(title → sections → notes + properties with int/float/bool/string values).
The command gathers all explainers into one catalog and owns text, JSON,
and HTML rendering — the library produces data, never formatted text.

The discipline that makes it honest: **the explainer calls the same
fold the transform runs.** `explain` executes on the *pre-transform*
tree — it runs instead of compilation, before any `facet_decl` node
exists — so `std/refine`'s explainer walks the same `std/refine` blocks,
the same anchor resolution, and the same meet that the transform would
emit. `metFields` is the fold as a comptime API: a consumer's explainer
(`std/list`, later `std/store`, a JSON decoder) asks "what does this
type's facet meet to" and gets the same `[]Field` the transform emits —
one producer, several sinks, no drift. An explainer that re-interprets
the source is a second transform and will lie.

The pre-transform placement is a feature, not a limitation: it is the
only surface that can explain a program that refuses to compile.
`671_019` pins it — an orphan refine and a bound on a `string` terminal
each report `refused: <reason>` while the compiler's own diagnostic says
the same thing. "Why did my program refuse?" is the highest-value query
explain can answer.

Two corollaries observed while landing it:

- **The consumer's explainer correlates by identity, not linkage.**
  `std/list`'s explainer doesn't know refine; it calls
  `koru_refine.metFields` when the module exists and reports "pushes
  unchecked" when it doesn't. The two reports join on `home:Name` in
  the catalog — how "who enforces this?" stays honest without refine
  knowing its consumers.
- **Reports read the declared vocabulary, not the lowering.**
  `port: Port & >1024` reports `Port` and resolves `Port → i64` for the
  scalar property — the user reads what they wrote, the tool reports
  what it resolves to.
- **A name-composing transform's fold is its sites, not its output
  decls.** `std/pump`'s `run` enumerates joins by scanning generated
  `__pump_<name>_step_<i>` decls — which don't exist at explain time.
  The explainer's equivalent fold is the *document order of the
  `std/pump(...)` sites themselves*, checked with the same legality
  rules (step required, `! wait` needs `! live`, callee contract via
  `PH.calleeDecl`). Same membership, same order, same refusals — a
  different enumeration surface because the wire it reads is the
  program, not the product.
- **Refusal wording is shared, not mirrored.** `std/pump` keeps every
  KORU161 text in a `PM` const block (`pump.messages.kz`); the
  transforms pass them to `ast.refusal` and the explainer formats the
  same consts for `status` rows. The report for a refusing program is
  the diagnostic verbatim — one string, two sinks, and no way for the
  explanation to drift from the error it explains.

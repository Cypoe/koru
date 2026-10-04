---
type: belief
id: frag-the-facet-question-is-parser-decidable
provenance: pre-commit gate work 2026-10-04 — the .k/.kz convention was about to be routed to Jev ("inference over a diff might not see it; feed the judge more data") when the census showed the parser already computes the answer
ts: 2026-10-04
---

# The facet question is parser-decidable — judgment-shaped is not judgment

The `.k`-vs-`.kz` convention spent its life enforced by memory plus a
sweep lint, on the theory that "should this file be `.k`" is a judgment a
reader makes from context. The session framing was inference-shaped:
maybe the diff doesn't show enough; maybe feed the judge more data.

The parser already answers it. `--check-k-convertible` (in the tree since
July, fb68bce73) classifies a `.kz` by its top-level AST: any non-comment
`host_line`, `host_type_decl`, or `proc_decl` and the facet is earned;
zero and the file is a `.k` wearing the wrong extension. The proposed
tilde-density heuristic — "if every meaningful statement needs a `~`,
it's Koru-native" — *is* the host_line count; the AST had been computing
the intuition all along.

The generalization, and the reason for the frag: **before routing a rule
to the reader — and before asking the judge for more context — enumerate
what the compiler already classifies.** The gate's designed split ("the
decidable get scripts, the readable get a model") makes decidability the
routing question, and decidable is wider than it looks: a property the
compiler computes for another reason is a free check. The inference
question was real; it was asked about a property that had been an integer
for three months.

And once the question is parser-decidable, the correction is
parser-verifiable: a compiler verb can refuse to emit any `.k` it has not
watched parse under the `.k` facet. `koruc <file.kz> to-k` is that verb —
the same item classification, then a mechanical `~`-strip, then a re-parse
of the output it is about to write. Conversion stopped being a script's
worktree ceremony and became a property of the emitter.

Where judgment genuinely remains — the **near-pure gradient**. A `.kz`
carrying 1–3 stray host items is Koru-native in shape but can't convert
without deleting or justifying the host line (`const std =
@import("std");` feeding emitted code vs accidental residue is a ruling,
not a parse). That is the class a *warning* belongs to, and koruc has no
warning class: `frontend_diagnostics` carries a `severity` field plumbed
to JSON/CCP but hardcoded `"error"` at both emit sites — warnings are a
producer plus an stderr render away, not a new architecture. Unruled.

Census at write time (1528 `.kz` files): 144 CONVERTIBLE (9.4% backlog —
56 positive tests, 64 error-marked, 24 other), 185 UNPARSEABLE (error
pins + `part` files that don't standalone-parse), the rest honestly
`.kz`. The gate row `kz-extension-is-earned` (diff-scoped, staged blobs)
holds new debt at zero; the backlog belongs to
`challenges/032_the_facet_sweep` — `scripts/kz_sweep_manifest.py` lanes it,
`to-k` does each mechanical conversion, `kz_convertible.sh --verify` still
owns mass compile-gating.

Open: the warning severity class (a suppression spelling is new surface —
Lars's ruling); whether the M-filter's touch-to-own ratchet on backlog
files bites (flip AMR→A if it does).

---

*2026-10-05, error-pin lane closed.* The 59-file `error-pin-review` lane
was the facet question's hardest case: CONVERTIBLE files inside
error-marked dirs, where "is the refusal about the file's facet" looked
like judgment. It mostly wasn't — **58 of 59 converted; the refusal fires
identically under `.k` in every case measured.** The one keep
(`140_029_dup_tor_across_facets_refused`) is facet-bound by construction:
the pin *is* cross-facet duplication, so a `.k` twin changes what it
measures.

Three classes the lane teaches, all cheap to apply:

- **Coordinate drift is not a verdict.** `expected_patterns.txt` /
  `expected_error.txt` that pin `input\.kz` or line numbers fail on a
  converted file with the *same* refusal — refresh the coordinate, keep
  the pin. (`210_014`: identical KORU021, only the filename in the
  diagnostic moved.)
- **A red pin stays red under conversion.** `335_056` pins the
  `std/io:free` spelling that normalization still strips; `.k` doesn't
  touch it. Redness is the test's state, not the facet's.
- **Explicit verdict beats dir heuristic.** `exempted()` returned
  "sibling MUST_ERROR" before consulting the allow file, so an
  error-dir keep could never take an allow entry — allow now wins.
  Heuristics propose; recorded rulings dispose.

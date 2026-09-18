---
type: belief
id: frag-a-site-hash-is-a-transient-fuzzy-address
provenance: koru session 2026-09-17 — site_hash.zig landed: glance emits
  hashes, `at` resolves by descent, explain rows carry `at` witnesses;
  690_319/690_320 pin the witness loop end to end
ts: 2026-09-17
tags: [koru, explain, glance, tooling, agents, architecture]
---

# A site hash is a transient fuzzy address, not a permanent marker

`src/site_hash.zig` gives every addressable node — decl, flow-head,
nested invocation site — a coordinate over the semantic path
module → item → site → nested site → …, one 3-char segment per level,
rendered shortest-unique so a shallow program never pays for the depth
its neighbours don't use. Each level emits a 3-char segment of a
chained digest, so **the hash is its own trie key**: chomping the right
side zooms OUT (right neighborhood, coarser cell), never off the map.

The earlier framing — permanent markers maintained across refactors —
was rejected: nothing is registered, nothing rots. The hash is a pure
function of the tree, minted fresh at report time. Drift is absorbed two
ways: ordinal-in-context keys (inserting an unrelated flow does not
shift a sibling's address) and `resolve`'s longest-prefix descent — a
stale hash lands at the deepest cell that still exists and reports
"tail drifted" rather than missing.

Corollaries that fell out:

- **Counted rows carry witnesses.** `inserts = 1 [deadb]` is the count
  AND its sites — `Property.at` is `[]const []const u8`, so a count is
  `witnesses.len` by construction and can never disagree with itself.
- **The catalog joins across modules on the coordinate.** `std/pump`'s
  `j0.step` row carries the call-site hash AND the `std/store:new`
  generator hash — the same hash `std/store` stamps on its own
  `participant` row. Two explainers that never meet share a coordinate.
- **Explainers must pointer-walk the real tree.** `for (items) |entry|`
  copies; `hashOf` then never matches. Witness-bearing folds iterate
  `|*entry|` — the pointer IS the identity.
- **`at` needs no tree knowledge.** Children of a site are sites whose
  hash has its hash as a one-level-longer prefix — matryoshka drill-down
  is a prefix op over the flat site list.
- **A coordinate and a location are different surfaces.** The hash is
  path-shaped; the `file:line` beside it must answer from the tree, not
  the flattened text. `stitchPipeChainLines` fused `|>` links into one
  string and stamped every step with the chain head's line, and the
  injected compiler import pushed continuation locations one buffer
  line past every user line — so `at` named sites on the wrong lines.
  The fix is per-link provenance at stitch time and user-coordinate
  translation at the read surfaces (`at`, `--ast-json`); stored
  locations stay parser-coords, because diagnostics and internal
  uniquifiers are already correct in that space.
- **The address space must cover every site a fold can count.** The
  first cut capped the path at four levels, so a `! first` nested four
  invocations deep under `| row a |> … | row b |> …` was counted by the
  store's fold but had no coordinate — `queries = 4` beside three
  witnesses, the self-disagreement the first corollary said was
  impossible. The invariant "count is witnesses.len" holds only if the
  enumerator and the folds agree on what a site is; a depth cap on one
  side is a silent disagreement. Koru pipelines nest deep by design, so
  the cap is generous and the render pays for depth only where it exists.

`glance` is the map (decls + hashes + file:line), `explain` the ledger
(decisions + witnesses), `at` the drill (hash → site → children). One
enumerator serves all three — same tree, same pointers, same hashes.

---
census: std/store
measured: 2026-09-11
against: koru main 20e956d78
consumers: ~4,000 .k/.kz files — koru suite, koru-libs, kopium, orisha, misc ~/src
---

# std/store — the one organ that is all transform, no runtime

13 files: `store.kz` (hub, `~part`-joins 12 verb files) + one file per verb.
**Every** `~pub tor` is `~[keyword|comptime|transform]` — per
`frag-store-is-a-transform-not-a-runtime-library`, the whole namespace is a
program-rewriting surface; there is no runtime library underneath to census.

## The table

| tor | classification | evidence |
|---|---|---|
| `query` | live — transform (`claims_descendants`) | 850 sites; the row sweep, store's workhorse |
| `stored` | live — transform | 829 sites; the ambient field-write join |
| `new` | live — transform | 785 sites; declares the store, owns default-value syntax (`hp: 30[i64]`) |
| `insert` | live — transform | 712 sites; mints the row handle `\| row rh` |
| `take` | live — transform | 101 sites; mints `<taken!>` phantom, KORU161 wall on malformed heads |
| `rule` | live — transform (`claims_descendants`) | 52 sites; row-level subscription + imperative sweep ("rung two") |
| `watch` | live — transform | 43 sites; plus receives everything `default` reroutes |
| `view` | live — transform | 11 sites; projected multi-store vocabulary (`view(Entities) { Player, Enemy }`) |
| `stripe` | live — transform | 9 sites; same-shape union sweep |
| `preorder` | live — transform (`claims_descendants`) | 8 sites; DFS forest walk over `[tree]` stores |
| `clear` | live — transform | 4 sites |
| `default` | live — transform (`[pre]` keyword) | **zero literal `store:default` sites** — it IS the 9 `std/store(name)` bare-reference sites, rewriting to `watch` before `create` scans |

## Ghosts — names in consumer sources that are not store tors

- `std/store:sweep` (15 sites) — **stale spelling**, one example
  (`koru-examples/todo/d_turns.k`, uncompilable today on missing `app/auth`);
  the sweep function is `query`'s `!` branch. **→019** — update or retire the
  example.
- `std/store:taken` (7 sites) — the `taken!` *phantom* `take` mints, referenced
  in test comments; not a tor.
- `kind`, `set`, `create`, `union`, `give-back`, `discard` (13 sites) —
  **aspirational spellings** inside showcase tests, marked `INVENTED:` in
  their own comments (690_296, DESIGN.md O2/O10 floats). Honest as pinned
  futures, but they wear the same `std/store:` spelling as real tors — a
  reader cannot tell imagined surface from shipped without reading the
  marker. **task** — an aspirational-spelling convention (the `~[
  aspirational]` tag exists for impls; nothing marks imagined *surface*).

## Seams

- **`take(store[0])` compiles and is a permanent no-op.** The KORU161 wall in
  `store.take.kz:80-107` refuses missing and malformed addressing heads —
  but a *well-formed* bracket carrying a literal int slips through to
  `__koru_row_of`, which can never resolve it (brand 0 is never minted;
  `frag-store-take-by-index-orphans`). The refusal exists for *shape*, not
  for *literal-ness* — a literal in the bracket is statically knowable.
  **→010** — `take(store[<int-literal>])` should refuse at compile time.
- **`rule.kz`'s header says `STORE.QUERY`** — copy-pasted documentation from
  the verb it forked; the comment lies about which file you're in. **→019**
  — one-line fix, rides any cleanup pass.
- **The reactive front door is three names for overlapping machinery** —
  `default` (`std/store(name)` bare ref) rewrites to `watch`, `rule` is
  "rung two" of the same subscription family, and `preorder`/`stripe`/`view`
  are specialized sweep forms. Nothing is *wrong* — but six read-side verbs
  (query/stripe/view/preorder/watch/rule) is the evolved long tail; a
  designed surface would say which of these is the general case.
  **task** — documentation/surface decision, not a deletion.

## Verdict

Designed *in its bones* — every verb is a transform with a KORU161 refusal
wall, and the ghosts in consumer sources are aspirational pins, not lies —
but the literal-index hole in `take` and the stale `sweep` example are the
two live defects this organ still carries.

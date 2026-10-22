---
type: belief
id: frag-a-field-typed-by-a-grid-name-is-a-certified-index
provenance: Goose-race primes narrowing + typed grid-index fields,
  697_022_grid_idx_field, 2026-10-22
ts: 2026-10-22
---

# A field typed by a grid name is a certified index (belief)

`nd: 0[tn]` in a `std/grid:new` cell block does three jobs that `0[i64]` —
or even a hand-narrowed `0[u32]` — cannot: it names the grid the cell
indexes into, it derives the narrowest unsigned storage from that grid's
extent (`IntFittingRange(0, size - 1)` — a `size:` bump re-derives the
width instead of silently overflowing), and it makes the cell's contents a
proven index.

The proof is bought once, at the write. `std/grid:stored` routes the value
through the target grid's own `__koru_at`, so an out-of-range int traps at
insertion naming the target — the panic edge moves from every access to
the single moment the cell is set. Every later `tn[que[i].nd]` is then
certified: it lowers through `__koru_wide`/`__koru_intcast` with no floor,
the same shape a minted sweep/for cursor already earned. Goose achieves
the same elision by program analysis; here it is a property of the field's
declared type — the name IS the proof.

Two edges are load-bearing, and both were pinned rather than assumed:

- A value already proven for the same target passes through a write bare —
  `rn[d].nd: rn[s].nd` moves a proof, it does not create one, and
  re-checking it cost +14M instructions on the primes kernel before the
  pass-through was added.
- Arithmetic kills the proof. `tn[que[i].nd + 1]` parses the same
  `grid[..].field` prefix, but the certification was about the cell's
  contents, not arithmetic on them — the read-side test requires the field
  read to be the WHOLE index text, so the expression keeps its floor.

The honest cost: writes of unproven ints pay the check they always should
have — primes (write-heavy, and its hottest deref is `fc + k` sibling
iteration, correctly floored) ran ~+4% cycles against the hand-tuned u32
kernel, byte-identical output. The feature wins on link-following shapes —
`tn[que[i].nd]` direct dereference — where the per-access floor genuinely
disappears, and on declaration honesty: `0[tn]` says what the cell IS.

Pools as index targets are refused at declaration: a pool's extent arrives
at alloc, so it cannot size a cell at `new` time — `usize` remains the
spelling there.

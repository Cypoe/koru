---
census: std/list
measured: 2026-09-11
against: koru main 687934e14
consumers: ~4,000 .k/.kz files — koru suite, koru-libs, kopium, orisha, misc ~/src
---

# std/list — the comptime-generic organ: one API, one hidden surface

7 part files, 12 pub tors = 6 generic entries + 6 `-i64` instantiations.
This is where the transform-target layer is load-bearing by *design*:
`std/list:new(i64)` rewrites to `new-i64` (list.new.kz:45, `"new-{s}"`
segments), and `push`/`get`/`len`/`pop`/`free` route the same way via
`routeOpCall`. Proto element types synthesize a whole container module
(`synthesizeContainer`) — generics-by-rewrite.

## The table

| tor | classification | evidence |
|---|---|---|
| `new` / `push` / `get` / `len` / `pop` / `free` | live — transform entries | 42 / 49 / 19 / 23 / 13 / 70 sites; all `~[comptime|transform]` |
| `new-i64` | transform-target **+ test-spelled** | 5 direct sites (white-box tests bypass the transform) |
| `push-i64`, `get-i64`, `len-i64`, `pop-i64`, `free-i64` | transform-target | 0 direct sites — reachable only through `routeOpCall` |
| `List_i64` | type ref | 4 sites (phantom-typed params in tests) |

(Census tooling note: tor names with digits need `[0-9]` in the call-site
pattern — an earlier pass truncated `new-i64` to `new-i` and misread the
family as dead. The brief's grep is now digit-safe by implication; a real
future pass should make it literal.)

## Seams

- **The hidden instantiation surface is half the pub list** — 6 of 12 pub
  tors exist only to be routed to. Not a defect — the design works — but
  it means `list`'s *visible* API (6 generics) and *exported* API (12 tors)
  diverge by construction. Same costume problem as `[norun]` impls, at
  family scale. **task** — the visibility ruling, again: one surface
  marker that says "instantiated, not spelled."
- **`new-i64` is test-spelled directly** — white-box tests bypass the
  transform to hit the target. Legitimate for tests, but it means the
  `-i64` surface is load-bearing at *two* layers: emission target AND
  test-callable API. A future rename must remember the second. **task** —
  naming-rule consequence, note only.
- **The proto-synthesis path is the deep end** — `synthesizeContainer`
  mints a whole module per element type; `push` on a proto-elemented list
  has no hand-written target at all. That's the most ambitious transform
  in std and it is exercised only through tests — **task** — the
  adoption question belongs to whoever drives collections next.

## Verdict

Designed — the comptime-generic bet is fully realized and honest (every
entry is a transform, every target is routable, phantom obligations on
`List_i64<list!>` carry through); its only seam is that the pub list says
12 where the language-visible API is 6.

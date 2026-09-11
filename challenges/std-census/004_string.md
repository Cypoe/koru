---
census: std/string
measured: 2026-09-11
against: koru main d4e586f3d
consumers: ~4,000 .k/.kz files — koru suite, koru-libs, kopium, orisha, misc ~/src
---

# std/string — one file, coherent ownership vocabulary, two dead tors

`string.kz`, 17 `~pub tor`s. This is the healthiest organ censused so far —
the `view!`/`instance!`/`allocated!` phantom vocabulary is load-bearing and
uniformly used (`String` 224 type refs, `instance` 118).

## The table

| tor | classification | evidence |
|---|---|---|
| `free` | live | 356 sites; the `instance!` discharger |
| `from-page` | live | 296 sites; THE entry — copies a `string` into an owned `String` |
| `take` | live | 225 sites; `view→instance` promotion |
| `append` | live | 205 sites |
| `clear` | live | 69 |
| `pop-char` | live | 66 |
| `read` | live | 55; the borrow (`<view>`) — the tor KORU095 guards |
| `append-char` | live | 34 |
| `view` | live | 23 |
| `len` | live | 16 |
| `format` | live | 14 |
| `split` | live | 13 |
| `parse-int` | live | 6 |
| `substring` | live | 4 |
| `from-int` | live | 4 |
| `release` | live | 2 |
| `index-of` | live | 1 |
| `contains` | live | 1 |
| `new` | **dead — unspellable** | 0 sites AND uncallable: `new { allocator: std.mem.Allocator, text }` takes a Zig type no Koru source can name. Not emitted by any transform (grepped `koru_std/*.kz`, `src/*.zig`). **→019** — delete or re-skin as `from-page`. |
| `snapshot` | **dead — designed, never adopted** | 0 sites; the designated escape-copy tor ("genuine escapes copy out through this tor"). Callers needing an owned copy reach `from-page` (296 sites) and do its job by hand. The designed path exists; usage routes around it. **task** — either the need is real and the spelling failed, or `from-page` already is the surface and `snapshot` is a comment's idea of the world. |

(`String` 224 and `instance` 118 in the grep are type/phantom refs, not tors.)

## Seams

- **A pub tor whose param is unspellable.** `new`'s `allocator:
  std.mem.Allocator` is a Zig type with no Koru spelling — the tor is
  pub-exported yet unreachable *by type*, not just by usage. The surface
  contains a door with no keyhole. **→019**.
- **The designed copy path lost to the raw one.** `snapshot` exists for
  escapes; everyone uses `from-page`. Either `snapshot` should be the
  documented spelling (and `from-page` narrowed) or the honest move is
  deleting the aspirational tor. **task** — a ruling, not a replay.
- Otherwise quiet: no naming-generation drift, no duplicated arms, honest
  `| err` branches throughout — this organ shows what the surface looks
  like when one ruling (borrow/copy phantoms) was applied on purpose.

## Verdict

Designed — the only organ so far where the pub list and the usage map agree;
its two dead tors are a door with no keyhole and a designed path nobody
walked, both cheap to resolve.

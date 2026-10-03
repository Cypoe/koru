---
type: belief
id: frag-a-canonical-name-should-be-its-surface-spelling
provenance: diagnostic-spelling investigation, 2026-10-03 — a sibling-fuzz
  finding's KORU021 blamed severed arms on `std.io:print.impl`, a name no
  source file can produce; the parse-boundary `/`→`.` coercion turned out
  to be the only reason the shape exists
ts: 2026-10-03
---

# A canonical name should be its surface spelling (belief)

Koru's parse boundary normalizes the module qualifier `/`→`.`
(`lexer.zig parseQualifiedPath`, with `canonicalize_names.zig` as the safety
net), so every internal canonical name is dot-joined: `std.io:print.impl`,
`std.io:free`, `std.io:print.blk`. That coercion is a legacy conflation —
it exists because the dot-namespace form once did, and the June ruling
(`5f41236fc`, "we won't accept both") retired the *spelling* while keeping
the *storage* it produced.

The language owes nothing to the past, so the conflation buys nothing and
costs twice:

1. **Diagnostics lie.** Anything that prints a canonical name emits a
   spelling the parser refuses — `std.io:print.impl` in KORU021 (the shape
   KORU035 explicitly rejects), `Call: std.io:free` in KORU030, hardcoded
   `std.io:print.blk` literals in `io.blk.kz`. The user cannot paste what
   the compiler tells them to write.
2. **A real shape is unrepresentable.** With canonical names collapsed to
   one alphabet, `app/graphics.subsystem:tor` and `app/graphics/subsystem:tor`
   are the same string — so a literal `.` inside a namespace segment (a
   module file `graphics.subsystem.kz`, a versioned `parser.v2`) cannot
   exist. Ruled 2026-10-03: dots must stay rejected *as separators*, but
   should be legal *as name characters* — a distinction the current storage
   contract cannot express.

When canonical = surface spelling, both costs vanish: `pathToString` output
is already correct (no display-side un-normalization layer), error text is
pasteable, and `app/graphics.subsystem` canonicalizes to itself. The KORU035
wall's job changes shape rather than disappearing — `.` stops being "the
old spelling, refused" and becomes an ordinary name character, so
`std.io:print.ln` reads as a reference to a module literally named `std.io`
(resolve-or-not-found, possibly a did-you-mean lint), not a parse error.

## Open questions

- The migration's blast radius is every site that constructs or compares
  dot-joined names: `parseQualifiedPath`, the canonicalize_names net,
  event-map keys, synthesized impl names (`std.io:print.impl` itself),
  `__store_giveback_*`/`__channel_take_*` discharger names, and literal
  keys in `koru_std` (`"std.io:print.blk"` maps). Contained only if
  canonical-name construction truly routes through one function — verify
  before promising the sweep.
- Does the KORU035 wall retire, or stay as a lint once `.` is a legal name
  character? A module named `std.io` next to `std/io` is a footgun either
  way.

Pinned red: `335_056_disposal_diagnostic_names_surface_spelling` — KORU030
must name `std/io:free`, fails today on `std.io:free`.

Related: [[frag-a-dedup-key-must-be-an-identity-not-a-spelling]] — canonical
form stays load-bearing; this redefines what it should *be* (the surface
spelling, not a parallel alphabet). [[frag-synthesized-phantoms-are-derived-names]]
— synthesized names minted at the boundary are writers through the same
seam, so they flip in the same migration.

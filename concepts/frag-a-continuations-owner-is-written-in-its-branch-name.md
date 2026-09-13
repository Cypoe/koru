---
type: belief
id: frag-a-continuations-owner-is-written-in-its-branch-name
provenance: asteroids JS lane, 2026-09-13 — the `consumed != 0` early return dropped the whole post-`~if` chain; the naive per-index drain instead ran a synthesized `| done` no-op and died on its `_auto_N` binding (the same failure that regressed 115_009/115_011 the first time the per-index drain was tried)
ts: 2026-09-13
---

# A continuation's owner is written in its branch name — named is the template's, unnamed is the caller's (belief)

When a template body (`~if`, `~for`) splices at a site, the continuation list
is a mixed bag: the arms the template dispatches (`then`, `else`, `done`,
`each`) and the chain steps the *caller* wrote after the template (`|> stripe
|> draw`). Both arrive in one array, and the `consumed` bitmask alone cannot
tell them apart — it only records which indices a `__koru_continue_N` /
`__koru_inline_N` marker named.

Two wrong rulings live at opposite ends of that ambiguity:

- **Trust the dispatcher wholesale** (`consumed != 0` → emit nothing more).
  Correct about skipped arms, wrong about the sequel: every `|>` step after an
  `~if` vanished — asteroids' frame body lost its entire draw section, the
  pump ran, and nothing rendered.
- **Drain per-index** (emit every unconsumed terminal). Correct about the
  sequel, wrong about skipped arms: a synthesized `| done` no-op (the
  optional-arm filler, its `_` renamed `_auto_N` by auto-discharge) drains
  into a binding with no result to bind — a compile failure — and a
  synthesized `@panic` hole would *fire* at runtime.

The branch name is the ownership signal the bitmask lacks. A named arm is the
template's vocabulary: if its marker was never minted — the arm synthesized
post-render, or the template deliberately not naming it — it does not run, and
skipping it is Zig-parity, not data loss (the Zig reference appends no
unconsumed terminals at all). An unnamed continuation is never the template's
arm — `continuations["X"]` can only name names — so an unnamed leftover is the
caller's sequel by construction, and it drains after the body, body-only: a
dispatcher produces no tagged result for a sequel to bind.

## The open edge

A `consumed == 0` site is a rendered statement, not a dispatcher — there the
named leftovers are the *caller's* (`=> ok` re-raises, produce arms the tap
transformer pushed down), and they still drain through the result-less
terminal path. The named/unnamed rule applies only where a marker was
resolved.

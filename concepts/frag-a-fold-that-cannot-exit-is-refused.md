---
type: belief
id: frag-a-fold-that-cannot-exit-is-refused
provenance: session 2026-10-01 — an external fuzzer (koru-fuzz, FUZZING.md)
  put `@L` on the arm it meant to exit and watched `| done` re-dispatch the
  head 14.5M times; the fix needed a ruling on what a terminal arm jumping
  back even means
ts: 2026-10-01
tags: [koru, labels, fold, termination, diagnostics, KORU206]
---

# A fold where every arm jumps back can never exit — refuse it, and make daemons spell their exit (belief)

`@L` is a back-edge on every arm — the jump decides, not the branch name.
`| done |> @L(...)` re-dispatches; `done` is not an exit because it is
called done. The exits are `->` produce, a `|>` continuation, or the arm
ending — anything that is not a jump. 247_label_fold_redispatch_exit_contract
pins both directions: a `done` arm that jumps back once (then `->` exits)
really does re-dispatch.

The one case the compiler can prove dead is a `#L` fold where EVERY terminal
arm's continuation ends in a self-jump: no arm exits, the fold cannot
terminate, no interpretation saves it. KORU206 refuses it in the backend
check-flow pass (post-transform, beside KORU021/022). The walk recurses arm
trees; it over-approximates "can exit" — a jump to an OUTER label, a missing
`else`/`done` arm, an opaque or grafted subtree all count as exits — so it
only refuses folds that are statically infinite.

The corpus held exactly one intentional infinite fold —
208_simple_server_flow's `#accept_loop`, a serve-forever shape that never
ran (COMPILE_ONLY). That is the ruling this belief carries: **a forever-fold
is legal, but it must carry an arm that can exit** — daemons declare their
`shutdown`. The alternative considered (refuse only value-position folds)
was rejected: it would leave the exact reported footgun — a void
tail-position fold — compiling silently, and tail-position forever is where
accidental hangs live.

What would correct this: an explicit forever surface (an annotation, or a
`serve`/`loop` tor kind) that makes "this fold never exits" a declaration
rather than an absence of exit — then KORU206 could relax for folds that
opt in, and the honest daemon stops paying for a fake shutdown arm.

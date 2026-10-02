# 800_008 — relay

**One-line pitch**: a courier line where a proc-minted pouch crosses a module seam and is retagged by pure Koru — backward, twice, inside a recursive retry.

**Tier**: resource-lifecycle (runnable).

## What it is

Nine dispatches leave a post desk. Each pouch is a `*Pouch` minted by
`lib/post.kz` (`took-pouch` → `<held!>`); the only discharge is
`file-dispatch` demanding `<!delivered>`. Everything between is pure
Koru in `lib/stamps.k`: `sign`, `wax`, `carry`, `arrive`, `turn-back` —
five tors that consume one phantom state off the pointer and issue the
next. The resource lives in `post.kz`; the obligation's entire middle
life is retagged in a *different* module. Two seam crossings per
dispatch.

Every fourth pouch goes express: `carry`'s union-consume `<!sealed|!held>`
takes it straight off the desk — the same signature accepting two different
entry points into the lifecycle. Every third is challenged at the pass:
`turn-back` consumes `<!carried>` and re-issues `<held!>`, a backward retag,
and the recursive `route` runs the pouch through the *whole* stamp chain
again. Dispatch 0 is both express and challenged — its pointer travels
held→carried→held→signed→sealed→carried→delivered.

## How Koru does the work

- **Obligation transfer across a module boundary**: `*Pouch<state!>` is
  minted and discharged in `post.kz` (proc leaves), but every stamp is a
  pure-Koru tor in `stamps.k` — `sign -> p` retags a foreign pointer's
  phantom with no host code at all.
- **Union-consume on a subflow**: `carry { p: <!sealed|!held> }` — two
  lifecycle entry points in one signature, no proc body (the catalog's
  other union-consume, `db.kz:begin`, is proc-side).
- **Backward retag + recursion**: `turn-back` re-issues an earlier state,
  `route` recurses — the checker tracks the obligation through the cycle.
- **Borrow mid-chain**: `peek-seal` borrows `*Pouch<carried>` back in
  `post.kz`, then the same `p` is consumed by `arrive` — borrow then
  consume on one handle in one flow.
- **Scalar phase token**: `i64<open!> → <closed!>` keeps run order a type
  property, closed by a consumer of `<!closed>`.

## Gaps I filled

- **Domain**: the three runnable rows are all bulk-populated stores swept
  by verbs. This is the first *single-resource protocol* — no population,
  one pouch at a time, correctness = lifecycle.
- **Language corner**: phantom retag of a proc-minted pointer by pure-Koru
  subflows *across a module boundary*, plus union-consume on a subflow
  signature, plus re-entering a consumed state in a recursive loop.

## Frontiers hit (toolchain bugs)

**800_009_if_arm_obligation_merge** — an obligation consumed in *both*
arms of an `if` is still 'live' at the merge: `send-all` originally
counted sends on a `|>` continuation after the `if` that routed each
pouch, and KORU030 blamed that line for the `<held!>` it believed
survived. Narrowed to a minimal repro and pinned. The count now rides
inside each arm, which is the honest shape anyway.

## Output

`expected.txt` — nine dispatches: express sends at 0/4/8, challenges at
0/3/6 (each re-entering `<held!>` and re-running the stamp chain), all
nine filed; the line closes `9 dispatched, 3 turned back, 9 filed`.

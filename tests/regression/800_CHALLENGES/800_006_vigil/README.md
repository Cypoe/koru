# 800_006 — vigil

**Pitch:** a sparse night watch — 64 sentries, 1/8 awake — where the
guard shape the ecs-store board measured at 2.03x (sweep all, touch few)
carries the program, and dawn empties everything by three different
verbs.

**Tier:** program-generation (runnable).

## What it is

`muster` bulk-inserts 64 sentries with every eighth awake, and mints 8
`*Relic<held!>` obligations into an owned column. `rounds` recurses five
deep over `patrol` (a `when s.awake == 1` query sweep — 64 visited, 8
written), `collapse` (a take-only rule sweep draining fatigued rows by
swap-remove), and `commander` (a `! first` query whose `| none` arm fires
once the last sentry stands down). Dawn raises `board.alarm`, drains the
relics through a take-only rule (each `| item` auto-discharging through
`release-relic`), `clear`s the sentries in one aggregate `! cleared n`
arm, and mints one fresh row into the emptied store to prove the
generation bump. The token threads `dusk! → night! → dawn!`.

## What it pressures

- **Guarded watch on a plural store.** `! fatigue f when board.alarm == 1`
  is a foreign guard: writing `board.alarm` re-announces `fatigue` on
  every live row. The plural `__store_announce_<T>` is `(row, field)` and
  a foreign write names no row, so the write arm fans out through a
  synthesized `__store_announce_each_<T>` sweep — 56 `fatigue 0` lines is
  the pin (64 mustered minus 8 culled).
- **Removal verbs, all three.** `take` fires `! removed` per row (the
  cull tolls `board.fell`), `clear` fires `! cleared` once with the count,
  and the owned-column drain discharges obligations per `| item` —
  `clear` on `relics` is refused by ruling, so the drain is a take-only
  rule sweep.
- **Sparse sweep + `| none`.** `patrol` writes 1/8 of rows per round;
  `commander`'s `! first` finds a survivor for three rounds and `| none`
  for two.
- **Cross-store ledger.** `board` accumulates `fell`/`gone` from
  interceptor arms on two different stores.

## Deliberately absent

- `! updated { old, new }` — a documented later-slice: the delta arm
  refuses to share a store with any field watch, and `sentries` carries
  the guarded watch this challenge exists for.
- `clear` on `relics` — refused by ruling: an owned row's obligation
  discharges one at a time.

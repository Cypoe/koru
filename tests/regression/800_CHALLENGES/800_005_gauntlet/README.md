# 800_005 — gauntlet

**Pitch:** a phantom-phased combat arena — muster, fight, score — where
phase order is a type property and no combatant can leave the world
unkilled.

**Tier:** program-generation (runnable).

## What it is

A 32-unit arena. `spawn-wave` bulk-inserts combatants through a counted
`for`, minting `*Unit<live!>` obligations into an owned column and writing
each row's handle into a grid. `pair-rivals` pairs combatants by indexed
writes (`arena[a.opp]`). `strike` is a compound-guarded query sweep
(`a.opp != -1 and a.hp > 0` — the dead don't strike); `cull` is a rule
sweep that `take`s dead rows (swap-remove), clears the survivor's
back-pointer AND pays victor's vigor — two writes through the same taken
payload handle (`arena[i.opp]`, the respell path). `rounds` recurses
strike/cull six deep. `tally` folds survivors into the score; a standing
`hp` watch accumulates `board.scar` off the transplanted write path. The
`honor` phase `! first`-extracts the front survivor mid-query, then
double-takes a fresh challenger's handle — the second take resolves the
stale handle into `| empty`, take's graceful absence. The gauntlet token
threads `open! → mustered! → fought! → scored! → honored! → closed`
through every phase — skip one and the program does not type-check.

## How Koru does the work

- **Obligations, twice.** `i64<open!>`-family tokens carry the phase
  machine; `*Unit<live!>` carries per-combatant liveness. `kill-unit` is
  the column's canonical void discharger, so every `take` and the
  arena's teardown discharge it automatically — the `board: N killed`
  trace is the `! removed` interceptor observing each death in
  swap-remove order (non-sequential ids are the tell).
- **Reactive arms.** `! inserted` / `! removed` maintain the `board`
  aggregates (alive, kills, vested pool) and print the cull trace. The
  `kills` watch prints the running board count; the `hp` watch folds
  every write to the hot column into `board.scar`.
- **The measured hot paths.** Counted-for insert, handle mint + grid
  pairing, indexed-resolve writes (incl. the same payload head respelled
  twice), guarded query + rule sweeps, take under `! first`, and
  swap-remove — the same operations the ecs-store benchmark board
  measures, assembled into a program that has to be right.

## Gaps / features targeted

- Obligation-typed store column (`*Unit<live!>` inside `store:new`) —
  owned-column machinery with a canonical discharger.
- Take-payload indexing (`arena[i.opp]`, twice per arm), conditional
  arms inside a take continuation, recursive tors, `when`-guarded
  sweeps incl. compound guards, a field-level `watch` on a plural
  store, `! first` + `| none` query arms, take-under-query-arm, the
  `| empty` take-miss arm via a stale handle, and interceptor ordering
  against swap-remove.

## Frontiers found (now fixed)

- **Discharger name mangling.** `store.new.kz` spliced the canonical
  discharger's kebab name (`kill-unit`) raw into emitted Zig; the call
  needed `kill_unit_event`. Fixed — both the emit splice and the
  dead-strip retain-match join through `appendMangled`.
- **`store[item.field]` self-FK collision** (pinned green at 690_339).
  `stored`'s index head read any dotted `base.field` as an FK traversal
  ("field OF row-handle base"), emitting `resolve(i)` on the `| item`
  payload struct. Fix: the index head now checks whether `base` is bound
  by an enclosing take `| item` arm — a row VALUE, so `i.opp` resolves
  the stored handle directly. The walk uses the site-view's `site_of`
  back-pointer to find the enclosing arm in the real program.

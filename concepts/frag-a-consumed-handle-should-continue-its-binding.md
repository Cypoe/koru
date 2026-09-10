---
type: belief
id: frag-a-consumed-handle-should-continue-its-binding
provenance: Lars design discussion 2026-09-10 (raylib `frames`/`activate`, db `tx.exec`); aspirational, unruled — pinned red at 336_007/336_008
ts: 2026-09-10
---

# A consumed same-typed handle is ONE entity advancing, not a value spent and a new one minted (aspirational belief)

A tor that consumes `*T<!s>` and re-mints `*T<s'!>` is describing the *same
entity* with a new state. Today the caller must model it as death-and-birth:
the consumed binding is spent, and the re-minted handle is re-bound under a new
name. Every rebind of this kind carries no information — the new symbol is the
old pointer with a new state, and the implementation already proves it
(`raylib`'s `frames` is `return .{ .done = win }`; `window.activate -> win` is
the transition written out).

The ceremony is real and visible:

- `raylib/tests/draw_per_entity.k`: `| win w |> frames(win: w, …)` … `| done w2 |> close(win: w2)` — `w2` is `w`.
- `raylib/tests/texture.k`: `activate(win: w): wx |> close(win: wx)` — `wx` is `w`.
- `koru` `336_006`: `begin(conn: c): t |> exec(tx: t): t2` — here `t2` is `t`
  (same base type, `Transaction`); the `c → t` and `tx → Connection` re-binds
  either side are legitimate (different base types, genuinely new entities).

## The rule this aspires to

The **sole same-typed survivor advances its input binding in place**. Named or
anonymous payload, branch or bare return — one rule. The disambiguating rebind
(several same-typed handles in flight) stays, because there the name is the
thing that says *which* entity continues. That is the arity line the language
already walks: `frag-pointfree-threads-the-branch-left` — *"name a branch only
when more than one is left; the sole survivor names itself."* The rebind is
that same hand-unrolling one level down, at the binding.

## Discovery: the correspondence is TYPE-based, not field-name-based

The tempting spelling — `window.paint { win: *W<!open|!active> } | painted { win: *W<active!> }`
— does not survive the parser: a single-field payload may not be a record
(`KORU003`: *"single field in braces — use identity syntax"*). So there is no
output field NAME to match on; the sole same-typed survivor is identified by
its **base type**, which is exactly where `frag-the-thread-binds-by-type` already
lands ("the name was carrying no weight"). The rule is type-based because the
language makes it so, not by preference.

## The eventual refusal (the lever, not the whole)

A legal-but-inferior spelling never migrates; it accumulates beside the good
one. So the advance should land *with* a refusal of the unambiguous rebind —
the KORU115 move (retire the spelling, teach the fix), not a discouragement.
**Sequencing is load-bearing:** refuse first and the only legal spelling is
gone, so the transition cannot be expressed at all. Advance and refusal are one
ruling; the corpus that taught the wart (raylib) is the corpus that proves the
fix.

## Open — and "hairy" by Lars's own flag

- Auto-threading already exists in some cases; the advance must not collide with it.
- `_` / auto-discharge: a discarded advanced payload must leave the obligation
  live on the input binding, not heal it away (`: _` currently auto-discharges
  an obligation-carrying payload — `frag-phantom-bind-chain-threading`).
- The anonymous-payload spelling for "this payload is an alias, not a new name."

## Pins (aspirational red)

- `336_007_same_type_handle_advances_in_place` — arrow/bare-return form
  (`advance -> h`), `| opened h |> advance(h) |> close(h)`. Red today:
  `KORU030 Use-after-discharge: binding 'h' was already discharged`.
- `336_008_branch_transition_continues_its_binding` — branch-payload form,
  same red. Flip both green when a consumed handle continues its binding.

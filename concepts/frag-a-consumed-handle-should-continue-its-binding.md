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

## Which output continues which — the written/unwritten line again

The correspondence is not one mechanism but the same bright line the thread
already draws (`frag-the-thread-binds-by-type`: *"what you write binds by name,
what you do not write binds by type"*):

- A **named** payload field — `| advanced { h: *Handle<active!>, n: i32 }` —
  continues the same-named input `h`; the name does the matching, and the other
  fields (`n`) are ordinary new bindings. (Contrived but real: the multi-field
  record is the shape where a name is writable at all.)
- An **identity** payload — `| advanced *Handle<active!>` — has no field name to
  write, so the sole same-typed input continues by type. This is the only legal
  spelling when there is a single output: a one-field record is refused
  (`KORU003`: *"single field in braces — use identity syntax"*).

So the rule reuses the chain's existing matching machinery at the binding, rather
than inventing a third mechanism. My first reading ("type-based, not name-based")
was half the story: the name matches where a name can be written, and the type
matches exactly where the language removes the ability to write one.

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

## Identity is invisible to the caller — the rule is base-type, not pointer

The signature cannot say whether the implementation re-tags the same pointer
(`take -> s`) or mints a new one (an allocating rebuild), and it should not have
to. The caller observes only two things from a transition: **(1) the base type**
— does my handle still exist, and as what — and **(2) the phantom state** — what
may I do next. Both are already in the signature. Whether a new value appeared is
implementation noise.

So the rule keys on the **base type**: a consumed binding whose sole
same-based-typed output is unnamed continues under its own name — allocation or
not. A **type** change gets a new name, because there the old name would lie
about what it holds (`begin`: `Connection → Transaction`).

No `tor`-syntax overload, and no mangling. The old binding is consumed *before*
the new value exists, so a second live value never shares the name — the emitter
reassigns one slot (`w = step(w)`). Mangling is owed only when two values are
live at once, which a consuming call rules out. (An SSA-shaped emitter may
freshen the symbol internally; that is invisible and semantically free.)

## Pins

Aspirational — published as `MUST_ERROR` (green today: each pins the current
refusal, `KORU030 … already discharged`, so the board keeps showing real
failures rather than intentions — the `330_071` convention). Flip to `MUST_RUN`
when a consumed same-based-typed binding continues; green then means the advance
landed.

- `336_007_same_type_handle_advances_in_place` — arrow/bare-return (`advance -> h`).
- `336_008_branch_transition_continues_its_binding` — branch identity payload.
- `336_009_named_payload_field_continues_its_binding` — named multi-field payload
  (`{ h: …, n: i32 }`): the NAME half.
- `336_010_continuation_is_identity_agnostic` — the implementation **allocates a
  new handle**; the binding still continues. The pin for "the caller cannot and
  need not tell."

Guard (must STAY green — the negative space that keeps the rule from
over-applying):

- `336_011_ambiguous_survivor_forces_explicit_binding` — two same-typed handles
  consumed, one minted: no sole survivor, so neither input continues; the old
  binding is spent.

### Boundaries not yet pinned
- A **borrow** (no `!`) is not a transition and must not advance or consume.
- A consume with **no returned handle** spends the binding (safety guard).
- The **thread/pun reaching further** (the hypothesis that name-continuity lets
  the sole-survivor thread carry obligations across more stages).
- The eventual **refusal** of the unambiguous rebind (the KORU115-style lever,
  sequenced with the advance).

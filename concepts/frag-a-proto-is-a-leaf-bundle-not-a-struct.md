---
type: belief
id: frag-a-proto-is-a-leaf-bundle-not-a-struct
provenance: composite-custody session 2026-10 — Lars reframed the channel question: "there is a reason we don't have structs in koru: everything looks like a struct but is a bunch of scalars being passed around with individual ownership tracking." The owned-leaf lift made the registry honest about that.
ts: 2026-10
tags: [koru, proto, obligations, registry, channel, design-ruling]
---

# A proto is a leaf bundle, not a struct — and a leaf may be a debt (belief)

Koru has no structs. What looks like a struct — a proto — is a named bundle
of leaves that expand independently at every consumer. Until this session
the bundle could carry only *data* leaves (scalars, nested compounds,
`ref(X)` handles): the registry knew shape but was silent about ownership.
Owned obligations lived in private grammars — store columns could spell
`*mod:Type<state!>` but proto could not (KORU173), so a compound carrying a
debt was under-described at the identity layer.

The lift: `*mod:Type<state!>` is now a proto leaf vocabulary, identical in
contract to the store's owned column — module-qualified so every consumer
can locate the type's canonical discharger, `!`-suffixed because a bare
`<state>` borrow is not owned. Like `ref(X)` the leaf is a reference — no
expansion, no cycle edge — but unlike ref it carries a debt the receiver
settles **per path**. `Env { r1: *Res<owned!>, r2: *Res<owned!> }` is not a
value that *contains* two obligations; `e.r1` and `e.r2` *are* the
obligations, addressed independently the moment the value exists.

Consequences that fell out, all measured:

- **`<:` extension unions owned leaves like any field** — multiple
  inheritance of debts composes for free (699_034).
- **Every proto consumer inherits the spelling** — and must handle or
  loudly refuse it. Rings and lists refuse (320_176, 698_019): they are
  plain-value transports with no custody edge. Channels transit per-leaf
  (699_031): `send | ok` consumes each path, the `!` arm's obligate mints
  each path, partial settle refuses KORU030 naming the standing leaf.
- **`recv` is not a composite-custody path** — `| some v` cannot mint
  per-path; arms are the spelling (699_033). The refusal teaches toward
  the arm form.
- **Bare proto returns seed per-path debts** — `-> Env` resolves through
  the registry to the leaf list, so `e.r1`/`e.r2` mint on binding; the
  field-granular machinery (frag-field-granular-obligation-narrowing)
  inherits it wholesale.

Why this is the right layer and not a channel-local grammar: "this field is
an owned resource arriving in state `live`" is *identity*, not layout. An
Envelope that holds a live File is a different thing than one holding an
i64 — proto's whole job is nominal identity, and a registry that cannot see
an owned field under-describes every compound that carries one.

## The Rust contrast, stated precisely

Rust can destructure what you own; it cannot destructure what you owe —
because nothing is owed. In Koru the channel delivers `v` as `v.r1` +
`v.r2`, two independent debts; settle one and the other stands at the
chokepoint. Reconstruction has a contract too: bundling leaves back into a
value re-enters them in the ledger for the next edge. Rust granularizes a
fused whole; Koru never fused it.

## Measured state (2026-10)

Pins `699_031`–`699_034`, `320_176`, `698_019` green; the six-pin family
plus the 022–028 whole-value custody pins all hold on the same board.
Subflow-implemented events (`=`-impls) remain carved out of field-obligation
seeding (330_100's ruling), so a composite producer is a pure event —
`mk-env { a: *Res<!owned>, b: *Res<!owned> } -> Env` consuming its leaves
in and producing the bundle out.

## Where this could be wrong

- **Store emission gap**: `{ env: Env }` store columns pass every phantom
  check — insert consumes, take re-mints per path — but Zig emission writes
  dotted idents (`__koru_out_env.r1`, `it.env.r1`) that are not legal
  identifiers. Measured as a *pre-existing* gap for ALL compound columns
  (scalar compounds break identically), not owned-leaf-specific — but until
  it is fixed the store cannot actually run a composite row.
- **Nested projection `r.outer.h` is still untracked** — the owned-leaf
  machinery reaches one projection deep, same ceiling as field-granular
  narrowing. A proto inside a proto carrying a debt deeper than one level
  is unmeasured.
- If a non-pointer owned leaf is ever needed (`Res<live!>` by value), the
  registry contract has no spelling for it — today's grammar requires the
  `*`, which is what makes "handle that owes" legible.

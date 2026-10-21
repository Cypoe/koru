---
type: belief
id: frag-dynamic-is-the-shape-the-decl-cannot-name
provenance: cs_emitter dynamic-fidelity pass 2026-10-21 — ~63 `dynamic`
  sites fell out of csType's 14-scalar table and treated "not in the table"
  as "not nameable". The lib surface proved the cost: 220_053's assembly
  was callable cross-assembly but not checkable — a wrong-typed consumer
  compiled and detonated as RuntimeBinderException. Pinned by
  220_054_cs_lib_typed_contract (the negative consumer: `hit.nope` is
  CS1061 at C# compile time).
ts: 2026-10-21
tags: [koru, cs, emitter, payloads, contract, dynamic, nominal-types]
---

# `dynamic` is the shape the declaration cannot name (belief)

In emitted C#, `dynamic` is not a type — it is the absence of a nameable
one, and it has a price: member access routes through the DLR call-site
cache instead of static dispatch, every value type boxes, and a public
member whose type is `dynamic` makes the whole contract callable-but-not-
checked — a wrong-typed cross-assembly call compiles and fails at runtime.

So the emitter's rule is not "use static types where convenient." It is:
**every shape the Koru declaration can name gets a name.** A record
payload gets a generated nominal `<b>_payload` struct nested in its event
class; a multi-arm effect resume gets `<arm>_resume`; branch-bearing
outputs get `Output` with one typed member per terminal; arm params and
optional resume delegates get `Func<in,out>` with the declared types.
`dynamic`, `object`, and anonymous objects all fail the same test — they
cannot be written in a signature, so no compiler downstream can check
them. A nominal struct is the only spelling that is both constructible in
the handler and nameable in the contract.

`dynamic` is still the right spelling — the only honest one — where the
declaration genuinely cannot name the members: wildcard payloads (`| b _`),
`Source` params (call sites hand anonymous records), and values that exist
to be membered through (borrow handles, `Func<dynamic>` closure fallbacks,
metatype captures). `object` is reserved for storage positions: a
payloadless `Output` member, an undiscriminated resume slot, the
`__KoruBox.data` carrier — places that hold bits but are never membered.
The distinction is membership, not "known vs unknown": `object` on a
membered-through value is a *worse* lie than `dynamic`, because `.h` on an
`object` refuses at C# compile time while `dynamic` at least binds at
runtime (690_356 measured this — an `object` return type broke `r.h`).

## The arity rule the helpers share

`HostShape.branchRec`/`armPayload` and the emitter's `payloadIsRecord`
agree through one invariant the transforms enforce upstream: a
single-field payload collapses to the value's own type (`__type_ref`
identity) — "a single-field record is a shape no author could have
written" (store.new.kz:4748). So `decl_fields >= 2` in the helpers *is*
the record predicate, not a tuple-era accident: `len == 1` only ever means
identity in transform-authored decls. The emitter keeps the wider
`payloadIsRecord` (1+ named fields) because user-authored `| b { x T }`
declarations exist there and get the same nominal treatment.

## Open question

A transform that mints a one-named-field record decl would slip between
the two predicates (`>= 2` helper, `>= 1` emitter). Today the arity rule
makes that decl unspellable; if a future transform relaxes it, the helpers
must take the fields, not the count.

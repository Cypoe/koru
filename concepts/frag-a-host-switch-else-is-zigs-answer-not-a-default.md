---
type: belief
id: frag-a-host-switch-else-is-zigs-answer-not-a-default
provenance: C-lane plural-store tranche, 2026-10-12 — `main_module___store_sweepbody_*` emitted as a C call name (the zig qualifier leaked through a host-relative helper) and `@as(i64, @intCast(__koru_si))` reached C output through a `[ordinal]` capture; both were `else` arms that were really `.zig` arms
ts: 2026-10-12
tags: [koru, c-lane, host-shape, qualifiers, else-arms, ports]
---

# An `else` arm in a host switch is somebody else's answer, not a default

`storeEventQualifier(home, main)` answers "how do I spell this event's
namespace on this host" — js flattens to `main_module.`, cs folds the home
into the basename, zig resolves the module path. A new host that falls
through to `storeEmitQualifier` gets **zig's answer** — `main_module.` names
a zig namespace nothing else emits. The C lane's first sweep emitted
`main_module___store_sweepbody_*` — a call name that exists on no lane —
because "the C qualifier is `home.`" was never asked; the `else` answered
for it. The same shape sat in `store.cursor`: `[ordinal]`'s capture spelled
`@as(i64, @intCast(__koru_si))` for every non-cs target, an `else` that was
really `.zig`, and C output gained a Zig cast until `validateNoZigInC`
stopped it at the gate.

The belief: **when a switch's cases are host spellings, `else` must name
the host it actually spells — or refuse.** Writing `else` is declaring "this
spelling is universal," which is true almost nowhere: every host folds
namespaces, casts, and qualifiers in its own spelling, and the fold that
differs is exactly what the switch exists to say. `.zig => ...` on the last
arm, or a panic that names the missing host, keeps the next port honest; the
unmarked `else` is how a zig spelling quietly becomes "the default C
spelling" too.

The dual of `frag-a-port-that-keeps-its-spelling-is-invisible`: there, the
instrument could not see a port that shared one body across hosts; here, the
shared body is real but the per-host branch silently inherits the wrong
sibling's answer. Both fail where a host-specific fact is inferred from a
shape that does not record it.

Cousin to `frag-the-inline-body-is-a-marker-carrying-contract`: the
`else`-spelling class is how a contract violation *arrives* — a host text
reaching the wrong lane unflagged until a gate downstream (validator,
oracle, segfault) names it.

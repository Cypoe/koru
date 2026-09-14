---
type: belief
id: frag-generated-bindings-join-the-users-namespace
provenance: 2026-09-14 — kopium hole 8, carried to koru: a ledger vocabulary
  module declaring `var name_len` collided with the generated dispatch_<scope>
  locals; pinned as 440_023
ts: 2026-09-14
resource: koru_std/runtime.kz
---

# Generated bindings join the user's namespace — all of them, at every scope

A `register` declaration derives a dispatcher whose emitted code lands *inside
the vocabulary module's own Zig container*. Every binding that emission
writes — the locals (`name_buf`, `input`, `v`), the parameters, and the
module-level implementation decls (`ScopeEvent`, `FieldValue`, `getArg`,
`buildInput`, `dispatcher_std`) — enters the same namespace the user's
module state occupies, under the host's rule that **containers do not
shadow**: a user `var name_len` makes the generated local `name_len` a
compile error, and a user `const Input` makes the event container's own
sibling reference `Input` ambiguous.

The rule: implementation-only generated bindings carry the `__koru_*` prefix
— Koru source cannot spell it, so the reservation is total. Protocol names
stay bare (`dispatch_<scope>`, `scope_events_<scope>`, `get_*_<scope>`, the
`pub` aliases) because the wire and other generated code name them by
convention. And inside a generated container that declares `Input`/`Output`,
its own signatures must qualify — `@This().Input` — because an unqualified
reference prefers ambiguity over resolution when the outer module declares
the same name.

The second hole in the same fix: dedupe of the emitted helpers was keyed on
the callee's module qualifier (`std.runtime`), but a merged `.k`/`.kz`
companion copies the `register` site to top level AND the module_decl, each
transformed separately — the winning copy saw the other's marker and shipped
helpers-less code. A dedupe key must name the entity being deduplicated —
the *site's* home items list, not the transform's own module.

What this does NOT cover: the user's own non-`__` names still collide with
each other across splices — that is [[frag-proc-body-internals-are-site-hygienic]].
This belief is the mirror direction: the generator protecting itself FROM
the user, where that one protects user producers from each other. The
mechanism both inherit is [[frag-nesting-a-module-inherits-its-parents-namespace]]
— the host's scoping rule, adopted wholesale by the lowering. Dedupe-key
discipline is [[frag-a-dedup-key-must-be-an-identity-not-a-spelling]].

---
type: belief
id: frag-emission-names-are-module-scoped
provenance: 2026-10-29 — koice.k; host.run's ! hotkey arm and a nested
  frames arm both emitted __HandlersCaps_4 (duplicate struct member at
  Zig emit). result_counter was flow-local; names land in main_module.
ts: 2026-10-29
---

# Synthesized emission names must be module-unique, not flow-unique

Emitter-synthesized identifiers (`Handlers_N`, `__HandlersCaps_N`,
labels, caps factories) land in `main_module` at module scope, so their
uniqueness domain is the whole module — never the flow they were
emitted inside. A flow-local counter (`result_counter`, a per-pump arm
index, a loop depth) is silently correct until a second pump site or a
second flow reuses the ordinal; the failure is a Zig-side
`duplicate struct member`, not a Koru diagnostic.

The ruling, 2026-10-29: every synthesized name takes `ctx.capture_counter`
(the existing module-unique counter) or an equivalent module-scope
monotonic. Found by koice.k: `host.run`'s `! hotkey` arm and a nested
`frames` arm both emitted `__HandlersCaps_4` — the consumer could not
shape around it. Fixed at all four `Handlers_{d}` emission sites;
nested-pump programs (koice, dictate) compile.

Open question for the enforcer: could analysis name this earlier? A
KORU-codeable "two synthesized decls would collide" diagnostic beats
Zig's error surfacing through the backend.

---
type: belief
id: frag-a-head-effect-arm-partitions-into-a-context-free-fn
provenance: 2026-11-04 — frontier-surface chasing mail_merge's "proc-effect arm sees module scope only" report: the raw Zig error ('tag' not accessible from inner function) became KORU207, pinned 400_208. Evolved 2026-10-15 — the emitter now carries captures across the partition; KORU207 is gone.
ts: 2026-10-15
---

# A head `!` arm on an impl flow partitions into a context-free fn — with a captures record (belief)

An impl flow whose HEAD call invokes an effectful decl partitions its `!` arms
into a synthesized `Handlers_*` struct (visitor_emitter phase 3b), passed
`comptime` to the call. The partition still happens — but the scope wall it
used to create is closed: when arm refs name enclosing bindings, the emitter
synthesizes a module-level generic factory `__HandlersCaps_N` whose container
`var` fields carry the captures. The call site instantiates
`Caps(@TypeOf(h), …)` — evaluated where the bindings are live, so no Koru-side
type resolution is needed — assigns each `__koru_cap_<name>`, and each member
fn opens with `const h = __koru_cap_h;` aliases. Zero-change fast path when no
arm refs an enclosing binding: the original local struct emits unchanged.

The factory must live at module level: Zig's no-shadow rule reaches into
local-struct member fns, so a `const h` alias inside a flow-nested struct
collides with the flow's own `h`. `CodeEmitter.deferred` is the channel — a
growable buffer flushed inside `main_module` before it closes.

Eligibility is the call site's live-bindings set (`zig_scope_bindings`, which
`emitContinuationBody` now registers prong payloads and destructure leaves
into, lexically popped) union the impl flow's tor params (`impl_event_decl`)
— excluding `_`, `__`-internal names, and branch-name collisions.

KORU207 is removed. What it refused was an emitter limitation wearing a
language rule's clothes — the checker refused what the emitter could simply
not yet express. The sweepbody Inputs already packed captures the same way;
the wall was that `Handlers_*` never learned the trick. Guarded consumer-site
arm groups benefit identically: multiple `! key-down` arms still merge into
one dispatch fn AND now see enclosing bindings — adding a guarded arm no
longer silently narrows sibling scope.

Still true:

- Mid-chain `!` arms inline into the frame — the enclosing handler's locals
  survive without capture.
- `[template]` procs lower by substitution — the arm never partitions.
- `[transform]` tors are consumed transform-side, not lifted.

Pins: 400_208 (`MUST_RUN` — the tor param crosses the impl-head partition and
the program runs), 400_209 (a prong-payload binding captured through a
guarded arm group, two nesting levels deep).

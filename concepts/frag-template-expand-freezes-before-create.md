---
type: belief
id: frag-template-expand-freezes-before-create
provenance: session 2026-07-23 (Lars + Grok) — todo_tui selection cursor; 690_074
ts: 2026-07-23
tags: [toolchain, store, template, lowering, timing]
---

# Template expand freezes Expression text before store:create can rewrite it

`|template|zig` procs (`if`, `for`, …) bake Expression arg text into
`Flow`/`Invocation.inline_body` at expand time. `std/store:new`'s cell-path
rewrite (`store.` → `__koru_store_<store>.`) historically only touched
transplanted watch/interceptor bodies and live Expression args. That is
**too late** for anything already frozen into `inline_body` — the emitter
reads the freeze, Zig sees undeclared `ui`, while the same `ui.sel` in a
later Expression (print interp, stored RHS) rewrites fine.

## The companion Zig trap

Whole-program Walk must mutate the live AST. `switch (n.*) { .invocation => |*inv| … }`
captures a **temporary** Invocation; assigning `inv.inline_body = …` is a
no-op on the real node. Arg rewrites still "worked" because `inv.args` is a
slice aliasing heap — that asymmetry hid the bug. Same family as Walk's
`|*f|` on switched Flow copies: mutate via `&pi.flow` / `n.invocation`, never
pointer-captures of switched union values.

## The trap has a second floor: the ROOT must be mutable too

2026-09-14, `! query` sweep arms (690_312): `walkCont` wrote
`n.invocation.inline_body = rewritten` — the *correct* form per above — and
the write still vanished. Read back inside the walk: the new slice. Read back
one function-return later in the caller: the original. The reason —
`walkCont(…, @constCast(&body_clone), …)` where `body_clone` was a `const`
local. Mutating through `@constCast` of a const binding is UB the optimizer
is entitled to discard, and here it did: the store was dropped while every
heap-homed write (arg slice elements, `continuations` children) still landed.
The asymmetry is the same one that hid the 690_074 trap — writes to *fields
of a const stack struct* die, writes to *pointed-at heap memory* live — which
is why the arg rewrite looked fine while `inline_body` never moved. The
contract is not just "write through a pointer"; it is "**the object the
pointer reaches must be `var`**". `store.new.kz`'s rule-arm walk escaped this
only because `qs.body` lives in an `ArrayList` backing, not in a const local.

## What this pins

Store create must Walk `inline_body` (and `inline_code`) after expands, and
must not use temporary-capturing switches when writing those fields. Pin
`690_074`. The belief is the *ordering* and the *mutation contract* — not the
rewrite regex itself. The sweep-arm twin of the same freeze is pinned by
`690_312`: `if(e.owner == …)` under `! query` lowers through the frozen text
to `__koru_srf_e_*` inputs, and `body_clone` is a `var` precisely so that
rewrite is allowed to exist.

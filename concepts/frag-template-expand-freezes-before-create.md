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

## The freeze has a second axis: the ARM LIST (2026-09-16, 330_046)

`inline_body` freezes not only Expression text but the *continuation list the
template rendered against*. A `[template]` proc's render bakes a
`__koru_continue_<idx>` marker per arm; `{{ continuations["done"].continue }}`
splices whatever arm existed at render time. When a later pass mutates the arm
list — the discharge inserter padding an omitted `| ?done`, or resolving an
anonymous `|>` arm — the new arm arrives AFTER the render, and its `.continue`
marker was never baked. The template lookup renders empty: the arm is in the
AST, its body (an inserted `close`) is in the AST, and the emitted Zig shows
neither — the resource binds `_auto_N` and never discharges.

So the mutation contract widens: a pass that changes an invocation's arm list
must re-render `inline_body` (nested) / `flow.inline_body` (head) against the
new list, not only avoid pointer-capture writes. The inserter now re-renders at
all three mutation sites — optional-arm padding, anonymous-arm resolution,
nested panic-arm synthesis. Pinned by `330_046`, `330_015`, `330_016` in their
omitted-arm spellings: the `| ?done` arm is synthesized, carries the discharge,
and emits exactly where a spelled one would.

**Why it survived:** every consumer spelled `| done |> _` — the arm existed at
render time, so the freeze was invisible. The wart's removal (KORU054 ruling)
made the omitted spelling the only legal one, and the latent staleness became
the load-bearing path. A synthesized arm invisible to emission is the same
shape as `frag-a-synthesized-safety-arm-only-exists-where-the-pass-looked` —
there the pass never looked; here it looked and the result never reached the
surface the emitter reads.

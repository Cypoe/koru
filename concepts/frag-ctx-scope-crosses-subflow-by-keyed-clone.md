---
type: belief
id: frag-ctx-scope-crosses-subflow-by-keyed-clone
provenance: koru_std/ctx.kz clone pass — 696_005..696_008 pins (2026-10-19)
ts: 2026-10-19
---

# Transitive ctx is keyed clone specialization, not shared-body rewrite

The question was whether a `std/ctx` scope at a call site should reach
inside the callee's body. It cannot be a textual substitution — a tor
emits ONE shared impl and different callers carry different scopes. The
answer that keeps both call boundary and zero runtime cost: specialize the
callee. `ctx(inner) |> needs-scope()` emits `needs-scope__ctx_inner`, a
decl+impl pair whose body is the original's rewritten under the scope
stack. `needs-scope` the author wrote is a template; the clones are the
code.

The design consequences that fell out, all pinned:

- The clone key is callee + ORDERED scope stack. `world+inner` differs
  from `inner+world` because stack order is shadow order.
- Row-subscript scopes lift their free variable into a clone input
  (`__ctxargN`), so `ctx(themes[i])` and `ctx(themes[j])` share
  `themes[__ctxargN]` — keying is on expression SHAPE, data stays live.
- Clone-on-demand is load-bearing honesty: a callee whose body
  (transitively) fills nothing keeps its shared impl — specialization is
  paid only by consumers.
- A template's decl is marked `[abstract]` when its impl drops, so a bare
  call refuses under KORU047 — the void-tor case matters most, because a
  dropped void impl would otherwise silently stub to a no-op.
- Recursion terminates by construction: `f` under stack S rewrites its
  recursive call to the same key `f__ctx_S`.

Two settled semantics worth repeating because they cost nothing at run
time: scope fields come from `std/store:new` schemas — a scope value that
names no store provides nothing and never guesses host-type fields; and
the emitted clone body contains ordinary injected args
(`ctxprobe(a: inner.a, ...)`) — there is no runtime resolver.

The koru-libs ancestor fragment `frag-ctx-is-a-scope-stack-resolved-once`
documented the call-site-only rung; this belief extends it across the
subflow boundary without changing the site-injection contract.

EXTENDED 2026-10-19 (component collision): exercising `ctx` against
`libs/ui:component`-generated tors surfaced the edge the splice drops. A
`std/ctx` step is a comptime no-op — its continuation node is removed and
its kids promoted — but the edge INTO it can carry real payload: a
`| row r` binder, a `!` effect kind, a `when` clause. Splice without
inheritance emits the scope's `theme[r]` reads with `r` never bound
(696_009 pins `insert | row r |> ctx(outer[r]) |> ctxprobe()`). The fix
copies the edge fields onto each promoted kid — the binding moves, it is
not replayed.

The same probe settled how ctx meets generated components: a
`component`-synthesized tor declares its props as ordinary inputs, so
`ctx(theme[r]) |> card()` injects `fs: theme[r].fs` AT THE CALL SITE —
the boundary crossing is the declared-input kind, and the generated impl
never clones because the transform emits complete calls (`consumes()`
finds nothing to fill). XAML-style ambient styling through components is
therefore prop injection, not clone specialization — the clone rung stays
for hand-written tors whose bodies leave calls unfilled.

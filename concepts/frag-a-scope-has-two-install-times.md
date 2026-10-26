---
type: belief
id: frag-a-scope-has-two-install-times
provenance: mounted-scope spike, 2026-10-23 — 440_056 (a bridge mounts a
  hand-built .dylib mid-session; the mounted verb borrows a base-minted
  handle through the shared pool, mints/discharges into the same ledger,
  and the hang-up sweep releases it through the module's dispatcher)
ts: 2026-10-23
tags: [koru, bridge, scope, mount, obligations, dylib, kopium, omni]
---

# A scope has two install times — a mounted scope is the register block's second installation, and the bridge is a scope set (belief)

The implicit prior was that a session's vocabulary bound once: `Bridge.scope`
a singular name, `buildScopeTable()` comptime-frozen, the hang-up sweep
consulting one scope's discharge tables. Growing verbs mid-session meant
restarting the interpreter — which kills the pool, because possession does
not persist. "Reload" was a polite name for "lose the resources." KOPIUM (an
agent whose only tool is a Koru interpreter) and Omni (a desktop whose kinds
arrive per-raft) needed the same missing piece: new tors compatible with
resources already held, without reloading them.

The ruling that fell out: **the loadable unit is the scope, and mounting is
a second install time of the register block.** A `.dylib` exports
`koru_module_init`, which returns the same `ScopeRuntime` vtable `register`
emits, and `std/bridge:mount` installs it beside the bound scope. There is
no second path: mounted dispatch is the same `Invocation`/`DispatchResult`
protocol against the same `HandlePool`; possession, wire-gate, input-field,
and arm-word checks read the mounted descriptor through the same lookups;
the hang-up sweep searches the whole scope set and dispatches through the
owning scope's dispatcher; `vocabulary()`/`grammar()` render mounted verbs —
and the mounted obligation legend, derived from the spec tables since a
module has no manifest record — through the same emitters. "The prompt and
the enforcement are the same bytes" survives the second install time.

The rulings inside it, which the code cannot fully hold:

- **Mount-for-life is custody, not a missing feature.** A handle's discharge
  path lives inside the dylib; `dlclose` while held orphans the disposer.
  An `unmount` that doesn't drain first is a refusal-shaped feature — the
  bridge closes the lib only after the sweep has run.
- **Mount is host-held.** The wire cannot reach it — a session may not
  install vocabulary on itself. Capability grows; authority doesn't.
- **Collision is a mount refusal, never a dispatch surprise.** Resolution
  stays defined → bound → mounted → host; a mounted verb never outranks
  what the session already owns, so owner lookup is exclusive by
  construction rather than by tie-break.
- **The ABI is same-toolchain by ruling.** The structs on the boundary
  (`Invocation`, `DispatchResult`, the spec records, `ScopeRuntime`) are
  compiled layouts, not serialized formats — `abi_version` is the
  handshake, not a compat story. A frozen C ABI (which would admit
  non-Zig modules) costs a translation layer; deferred explicitly, not
  drifted into.
- **The boundary crossing is function-pointer convention, not data
  shape.** The one bug the spike actually hit: an `export fn` (C
  callconv) called through a `*const fn` (Zig callconv) had its arguments
  shifted by a hidden result slot — the module read a stack neighbour as
  `services` and saw a garbage ABI version. Data declarations can mirror
  across the boundary; call-site conventions cannot be guessed — the
  lookup type must carry `callconv(.c)`.

What would correct this: a mounted scope needing descriptor shape the
compiled register cannot emit (then "same vtable" weakens to "mostly
shared"), or unload-with-drain becoming a real requirement (Omni raft
teardown), which corrects mount-for-life into a drain-then-close
lifecycle.

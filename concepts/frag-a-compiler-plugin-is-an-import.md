---
type: belief
id: frag-a-compiler-plugin-is-an-import
provenance: diag-bus worktree session 2026-10-21 — the SQLite diagnostic sink shipped as a koru-libs module file; the import was the subscription, the dep, and the registration, in one file
ts: 2026-10-21
tags: [koru, compiler, diagnostics, plugins, language-design]
---

# A compiler plugin is an import — the diagnostic bus makes the compiler's own events joinable (belief)

**The belief:** compiler extensibility does not need a registration surface.
When the compiler's own diagnostic stream is a joinable Koru event —
`std/compiler(diagnostic)` with `!` arms, collected by AST traversal and
erased before coordinate — a plugin is a module file: the join IS the
subscription, a `std/compiler:requires` block IS the dependency, and the
import mechanism IS the whole plugin system. `import koru/diag/sqlite`, an
ordinary koru-libs package path, wires a SQLite sink into the backend build
with no manifest, no flag, no `dlopen`.

## Why stderr stayed, and why that is not a compromise

The bus adds consumers; it never replaces the renderer. stderr survives
crashes the way a commit boundary cannot — the database is a derived sink,
not the channel. The renderer is effectively arm zero: a compile with no
joins behaves exactly as before, registry empty.

## Why a dedicated join, not taps

Compiler diagnostics are events OF the compile, not transitions IN the
program — there is no invocation in user code for a tap to match. A
compiler-owned join gives the right semantics for free: consumers are
statically enumerable (the same collection pass channel joins use), fan-out
is broadcast (each arm sees every diagnostic), and the world is closed at
compile time — the subscriber set is a fact of the program, not a runtime
table.

## The placement ruling

Dep-carrying sinks live in koru-libs (`koru/diag/*`), not stdlib
(`std/diag/*`) — the same namespace on two shelves. A stdlib that imports an
external library is a hard dep wearing an opt-in costume; the filesystem
placement makes the honesty mechanical. Eager submodule globbing is the
always-included trap in both places: a sink file loose inside an imported
directory subscribes every consumer of that directory.

## What would correct or narrow this

- Arms today resolve *names* against Zig-side builtins — the Koru spelling
  is the contract, the builtin the implementation. If a self-host or
  interpreter path ever runs user-authored sink bodies mid-compile, the
  spelling must not change when it happens; if it does, the belief was
  wrong about the mechanism being the surface.
- The barrier is backend-scoped by ruling: a `PARSE003` never crosses,
  because a diagnostic about parsing the join can't subscribe a sink
  declared by it. If a real consumer of frontend diagnostics appears, the
  placement — not the mechanism — is what gets revisited.
- Minted backends don't participate: arms are silently ignored there. That
  is a live gap — if it stays silent rather than refusing loudly, it is a
  defect to fix, not an exception to the belief.

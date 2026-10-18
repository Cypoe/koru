---
type: belief
id: frag-a-posix-hides-in-the-toolchains-own-paths
provenance: Windows verification pass, ccomp branch, 2026-10-12 —
  koruc --lang=cs on the Windows host failed three times before the
  first .NET byte ran: unescaped path literal, posix.getenv, open
  csproj handle
ts: 2026-11-05
tags: [koru, portability, windows, toolchain, emitters]
---

# frag-a-posix-hides-in-the-toolchains-own-paths

The host boundary is not only in emitted program text — every hand-off
the toolchain itself makes to the host (a spawned child's open of a
file we still hold, an env read, a path baked into generated source)
is a portability surface, and POSIX tolerates each failure mode so
completely that all three stay invisible until a Windows run.

Measured on `110_022` under `koruc --lang=cs` on the Windows host,
three independent leaks, each a silent-on-Linux default:

1. `emitInvocationMetaFields` wrote `.file = "<path>"` with a raw
   `write()` — `W:\src\...` produced `\s` invalid-escape errors in the
   generated backend. The escaping writer (`writeZigStringLiteral`)
   existed one call away; the site predated any Windows path.
2. `std.posix.getenv` does not exist on Windows (WTF-16 env); five
   debug-flag checks in `auto_discharge_inserter` plus `std/env` and
   `gate.helpers` used it where `std.process.getEnvVarOwned` was the
   codebase's own convention elsewhere.
3. `koru.csproj` was still open (`defer close()`) when `dotnet build`
   was spawned — POSIX lets a child re-open a file the parent holds;
   Windows refuses with MSB4025. The defer had to move above the
   `Child.run`, not merely exist in scope.

4. `Child.run`'s `.cwd_dir` handle (2026-11-05, `expression_codegen_
   compile_test`): on Windows the handle reaches the child as a `\\?\`
   device path, and the spawned zig's file-hash then cannot open the
   relative source name — `file_hash FileNotFound`, two unit reds that
   looked like a cache bug. POSIX resolves the handle to a plain path;
   the failure only exists where the hand-off format differs. Fix:
   `realpathAlloc` the dir and pass `.cwd` as a string.

The rule: when the toolchain touches the host — files it writes then
hands to a child process, environment reads, paths it bakes into
generated literals, the cwd a child inherits — POSIX-tolerance is not
evidence of correctness, it is the hiding place. A Windows run is the
cheapest portability instrument the repo has; run it before claiming a
lane works.

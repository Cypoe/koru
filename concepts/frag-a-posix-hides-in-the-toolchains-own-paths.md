---
type: belief
id: frag-a-posix-hides-in-the-toolchains-own-paths
provenance: Windows verification pass, ccomp branch, 2026-10-12 —
  koruc --lang=cs on the Windows host failed three times before the
  first .NET byte ran: unescaped path literal, posix.getenv, open
  csproj handle
ts: 2026-10-12
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

The rule: when the toolchain touches the host — files it writes then
hands to a child process, environment reads, paths it bakes into
generated literals — POSIX-tolerance is not evidence of correctness,
it is the hiding place. A Windows run is the cheapest portability
instrument the repo has; run it before claiming a lane works.

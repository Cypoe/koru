---
type: belief
id: frag-a-referenced-type-pins-its-home-module-into-emission
provenance: 667_005 — `std/foreign:struct(File)` in a same-file import left `*koru_app.koru_lib.File` dangling in emitted output; fixed by `collectTypeHomeModules` in visitor_emitter (2026-09-11)
ts: 2026-09-11
---

# A signature-referenced type pins its home module into emission (belief)

`collectModulesRecursively` decides whether a module enters the emitted file by
asking `moduleHasEmittableItems` — a runtime-surface question: events, flows,
host code that wants emitting. The answer was treated as a completeness test for
the whole module, and it is not. A module can contribute something that emits
while contributing nothing that counts: a host TYPE. A `.kz` whose whole payload
is `const File = struct {…}` plus a comptime `std/foreign:struct` registration
holds the declaration every `*File` in an emitted signature is qualified to
(`*koru_app.koru_lib.File` — the cross-module spelling of
[[frag-bare-host-type-is-module-local-cross-module-is-qualified]]), and the
collector dropped it while the qualification still fired. The emitted file
named a module it never wrote.

The invariant the emitter now maintains: **any base type named by an emitted
signature — event input, bare return, branch payload, host-type field —
pins its `host_type_homes` module into the collected set**, fixpointed because
a backfilled module's own signatures can reach further homes. "Emittable" is
no longer a property of a module's item list; it is a property of what the rest
of the program *references* in it.

The same conflation is worth watching for anywhere a collection pass treats
"has items I would emit" as "contributes nothing": emission is a reference
closure, and a declaration-only module is exactly where the closure's edges
terminate.

Measured 2026-09-16 (orisha + openssl consumer): the closure's edge was wrong
in the other direction too. A QUALIFIED spelling `?std.mem.Allocator` was
reduced to its last segment and fed to the same bare-name map — and
`const Allocator = std.mem.Allocator`, a private convenience alias inside
`[comptime]` std.compiler, had claimed `Allocator` first. Every consumer with
an allocator parameter welded the whole compiler module (imports of `ast`,
`log`, the pass machinery) into its runtime binary. Resolution now matches
how a reader resolves the spelling: **a qualified type names its own module**
(`std.mem.*` — no koru home, no pin; `orisha.Request` — orisha pins), and
`host_type_homes` is the fallback for bare names only. The map's first-wins
collision semantics are untouched — that ambiguity was already the contract
([[frag-bare-host-type-is-module-local-cross-module-is-qualified]] is the
spelling side).

Open: the scan still reads type STRINGS — a compound spelling like
`[]const [N]T` or `*const fn(...)void` names no home at all and escapes the
closure. No pin exercises that yet.

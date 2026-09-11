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

Open: the scan reads type STRINGS (`signatureBaseName` strips prefixes and
qualifiers, declines compound expressions), so a type reachable only through a
`[]const [N]T`-shaped spelling still escapes the closure. No pin exercises that
yet.

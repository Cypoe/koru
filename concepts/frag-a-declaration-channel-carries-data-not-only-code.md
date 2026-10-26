---
type: belief
id: frag-a-declaration-channel-carries-data-not-only-code
provenance: session 2026-10-22 — std/build:app landed (collector arm + Info.plist embed); the input-record false start measured the constraint
ts: 2026-10-22
tags: [koru, build, requires, comptime, declarations, bundling, macho]
---

# The requires collection channel carries declarations, not only code (belief)

`std/compiler:requires` and `std/build:requires` collect raw Zig text a build script
splices. `std/build:app { name: "…", id: "…", version: "…" }` rides the *same*
channel — a `[comptime|norun]` tor, a module-qualifier match in
`CompilerRequiresCollector`, and a synthesized `BuildRequirement` — but the payload
is **data**, not code. The pattern generalizes: any structured, per-program build
declaration (bundle identity today; icon sets, entitlements, signing profiles
tomorrow) is a tor whose block a named collector arm reads, not a new grammar
feature.

## The constraint that picks the spelling

A tor whose input is a *record shape* (`{ name: string, id: string }`) checks the
call site's named fields against the shape and then **drops the values** — the
serialized invocation carries `args: []` and nothing downstream can read what the
author wrote. A declaration meant to reach a collector therefore spells its fields
inside a `Source` capture (`{ source: Source }`, like `config`'s `{ "target": … }`):
the text survives in `arg.source_value` for the collector to parse and validate
itself. Named-field checking and collector visibility are mutually exclusive at
this grammar level — pick Source when the compiler, not the runtime, is the
consumer.

## Two rulings that came with it

- **Bundle identity is entry-program data.** The collector only honors the
  declaration at depth 0: an imported module that spells `std/build:app` is
  ignored — a library silently naming the executable it happens to link into would
  be an invisible override. `requires` aggregates across imports because every
  library's link needs are real; identity is a singleton.
- **Mach-O identity without a bundle dir.** `__TEXT,__info_plist` — emitted by a
  generated C source carrying `__attribute__((used, section("__TEXT,__info_plist")))`
  through `addCSourceFile`, since Zig 0.15's `std.Build` exposes no arbitrary
  linker-arg seam for `-sectcreate` — makes `NSBundle.mainBundle` answer a real
  `CFBundleIdentifier`/`CFBundleName` for an unbundled binary. Verified:
  `getsectbyname` self-read in test 906, and a probe binary answers
  `bundleIdentifier`/`CFBundleName`/`CFBundleShortVersionString` under
  `[NSBundle mainBundle]`.

What would correct this belief: if input-record bindings learn to serialize their
bound values (making the Source capture unnecessary).

## Evolve — the declaration gained a second consumer (2026-10-22, koru bundle)

`koru bundle <file.k>` assembles `Name.app/Contents/{Info.plist, MacOS/<name>,
PkgInfo, Resources/}` and adhoc-signs it. Two rulings fell out:

- **One generator, both carriers.** `emit_build_zig.appInfoPlistXml` produces the
  plist once; `appInfoPlistRequirement` embeds it in `__TEXT,__info_plist` and the
  bundler writes the same bytes to `Contents/Info.plist`. This is not cosmetic —
  `codesign` cross-checks the embedded section against the disk plist when it
  signs a bundle and refuses on mismatch. The "packaging makes the embedded
  section secondary" outcome this frag predicted is backwards: the embedded
  plist stays primary and the disk plist is generated to agree with it.
- **`CFBundleExecutable` is compile-time data.** Because the binary carries the
  plist before any bundle exists, the bundled executable's name (`MacOS/<name>`)
  is decided by the declaration, not by packaging flags — `-o` only renames the
  `.app` directory itself.

The bundled app closes the split-oracle gap the unbundled binary could not: an
`open`-launched `.app` arrives frontmost under its real name in System Events and
the full AX tree (unbundled binaries expose no windows to AX at all).

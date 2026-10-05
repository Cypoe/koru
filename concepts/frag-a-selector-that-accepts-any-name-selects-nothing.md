---
type: belief
id: frag-a-selector-that-accepts-any-name-selects-nothing
provenance: `koruc input.k --lang=cs` produced a working Mach-O executable — measured 2026-10-05 while scoping a .NET emission target; every lang other than `js` collapsed to the Zig emitter with no refusal
ts: 2026-10-05
---

# A selector that accepts any name selects nothing (belief)

`--lang` was documented as "the default variant tag — the value must match a
variant tag used in source." For as long as only `zig` and `js` were ever
passed, that contract read as a fact about the namespace. It was never one:
nothing checked it, so `--lang=cs`, `--lang=python`, `--lang=typo` all
compiled — and produced a Zig binary under the foreign name. A flag whose
legal space is enumerable-but-unenforced is not a selector; it is a comment
shaped like one, and the binary it ships is the proof the name meant nothing.

The general claim: **a selection mechanism earns its name only at the point
of refusal.** Everywhere a name selects something, the mechanism looks
identical whether or not the namespace is guarded — the guard is invisible
until someone passes a name that selects nothing. That is also why the defect
survives audits: every passing use is consistent with both the guarded and
the unguarded world, so the lie only surfaces on the path nobody walks.

## The admitted set is deliberately not "the emitter list"

The refusal could have been `lang ∈ {zig, js}` — a closed emitter registry.
It is instead emitters ∪ declared proc targets (full tags, plus bases with
`(...)`/`[...]` parameter groups stripped), because `--lang` is a *variant*
selector, not an emitter name: `|mlir` bodies AOT-compile into the Zig
output, and `raw_posix` is a real stdlib variant family — names that select
something under the Zig build. Refusing them would be a stricter lie than
the one being removed. The predicate mirrors the consumers' own comparisons
(emitter: `target == lang`; transform dispatch: base tag), not a reading of
the documentation.

## What stays open

- The CLI's *other* silent namespace — unrecognised flags absorbed into
  compiler_config — is the same class and is pinned-but-owed at 903.
- A tag that IS declared still emits through whichever emitter stage C
  selects: `--lang=cs` with `|cs` bodies in source passes the guard and
  produces Zig text with C# spliced in. The deeper wall (the tag names no
  emitter) belongs to the stage-C dispatch work, not the namespace guard.

---
type: belief
id: frag-bare-host-type-is-module-local-cross-module-is-qualified
provenance: Lars-ruled 2026-09-06 on the arbiter walk; trigger = yyjson import-order shadowing repro (kopium .claude/worktrees/repro-yyjson/headless/repro.k)
ts: 2026-09-06
---

# A bare host type is module-local; cross-module is fully qualified (belief)

A host (Zig) type name is bare inside the module that declares it. Across a
module boundary the signature spells it fully qualified — `*app/holder:Token` —
the same discipline invocations already follow (`koru/yyjson:parse`,
`std/bridge:run`). Qualified is not decoration on the bare form; it is the only
cross-module spelling.

## What this retires, and why the aspiration died

The prior rule blessed bare cross-module references resolved program-wide,
first declaration wins (the old 220_031; the homes map's documented collision
rule). The aspiration was "allow it when a single definition exists." The
implementation never checked uniqueness — and "only one definition" is a
whole-program property that silently stops holding when any import lands. The
repro: a program importing `std/interpreter` before `koru/yyjson` made yyjson's
OWN `*Value` signatures emit against interpreter's struct — a consumer's import
order rewriting a bystander module's internals. No per-module scoping guarded
the map. The spelling is retired not because it never worked, but because its
correctness depended on facts (provider count, import order) outside the
spelling's control.

## Consequences

- Module-local bare is unchanged and correct — holder's own `*Token` stays bare.
- The homes map's first-wins rule loses its only legal customer once the
  refusal lands; expect it to become a diagnostic aid or be deleted.
- The phantom-state doctrine
  ([[frag-bare-phantom-resolves-to-base-type-module]]) already assumed
  qualified base types ("the type carries its state's home"); this ruling
  closes the base-type half to match.

## Open — the migration scope is UNRULED

Sites pairing a bare host type with a qualified phantom
(`*String<std/string:view>`, `*List_i64<std/list:!list>`,
`*Map_string_i64<std/string-map:map>` — pinned at 660_027, 2112, 810_052,
610_007) refuse under this rule as stated. Whether stdlib signatures migrate to
`*std/string:String<...>` spellings, or the rule gets a scoped carve, is the
designer's open call. pump.k's `*Exchange` is NOT a refusal site: contract
`.k` + companion `.kz` merge as one module.

## Ruling landed 2026-09-06: no carve — stdlib migrates, refusal wires in

Lars ruled the open call the same day: NO scoped carve. Stdlib migrates to the
qualified spellings, and the frontend refuses bare cross-module references
(KORU115, src/host_type_scope_checker.zig) — enforcement before any transform,
so a refused program dies with the teaching diagnostic naming the fix
(`*app/holder:Token`). The four named pins migrated spellings-only; their
pinned observables held. What enforcement then DISCOVERED beyond the named
list, all migrated under the same ruling:

- koru_std's comptime transform plumbing wrote `item: *const Item` /
  `program: *const Program` bare in ~26 modules (io, fmt, store, list, types,
  …) — every program importing std/io refused until those 108 signature sites
  migrated to `*std/compiler:Item` / `*std/compiler:Program`.
- ~27 test-tree transform signatures carried the same retired spelling
  (220_013, 700_002/003/010/011, 210_03x, 310_052/124, 320_001/094, …) and
  migrated the same way.

The refusal is SET-based, not first-wins: a bare name is legal iff the WRITING
module itself declares it (HostTypeDeclSites, the set of declaring modules) —
on a two-provider collision (eval.Value / interpreter.Value) the writer's own
declaration still licenses its bare form, which the first-wins homes map could
not answer. The homes map keeps its emission role (module-local bare still
needs the Zig path qualification); it lost its cross-module customer.
orisha migrates later in its own repo (ruled out of this slice); pump.k's
`*Exchange` stays legal via the contract/companion merge.

## Refinement — ABI return keywords are protocol spellings, not host types

The board caught the migration over-reaching: a transform declaring
`-> *const std/compiler:Program` mis-emitted, because the transform machinery
string-matches its return BARE — `returns_program` (main.zig) and the
emitter's `ast_return_types` lowering to `__koru_ast.X`. So the carve the
refusal respects has TWO halves: PARAM positions are ruled-strict (a bare
foreign base refuses; `*std/compiler:Program` is the migrated spelling and
works), while RETURN positions carrying the compiler's own ABI keywords
(`Program`, `SiteResult`, `Item`, `ExplainReport`, the AST node names) keep
the bare spelling — they are protocol vocabulary, not module-owned host
types. A bare foreign NON-ABI return (`-> *Token`) still refuses.

## Emission half landed 2026-09-06: module-local bare emits writer-first

The enforcement half landed set-valued, but emission still resolved every
legal bare spelling through the program-wide first-wins homes map — the same
shadowing the refusal retired, still alive on the module-local half (the
yyjson repro compiled green through the checker and died in zig codegen,
yyjson's own `*Value` emitted as interpreter's). Emission now answers the
ruled question: the writing module's own declaration (the same
HostTypeDeclSites set the checker asks) names the emitted home. The homes
map's first-wins lookup lost not just its cross-module customer but its
module-local one too; what the Consequences section predicted ("diagnostic
aid or be deleted") landed as the diagnostic-aid half — a fallback for
positions the scope checker does not see (proc payloads) and for registries
armed without decl sites. ABI return keywords stay bare-matched (the carve
above is untouched).

## Refinement 2026-09-10: the qualified spelling must RESOLVE (KORU117)

The refusal required the qualified spelling and then stopped — `checkTypeString`
bailed on any `:` (`host_type_scope_checker.zig`), treating a qualified ref as
"the fix, never the fault." But the spelling is half: a qualified host ref names
a module, and that module must actually declare the type. Unresolved,
`*app/holder:Tokn` (typo) and `*app/wrong:Token` (wrong module) reached codegen
and surfaced as a raw Zig `has no member named` on an EMITTED ARTIFACT name
(`output_emitted.koru_app.koru_holder.Tokn`) — no source line, no Koru
diagnostic. That is the class shape_checker.zig names and avoids for KORU040.

KORU117 closes it: a POINTERED qualified ref (`*Mod:Type`, `?*const Mod:Type`)
must name a host type that its module declares, checked against the same
HostTypeDeclSites set. The pointer gate is the discriminator — host handles are
pointered, while proto/Koru terminals are value-typed (`app/alpha:Health`,
665_012/665_013), so value-typed qualified refs are untouched.

The headline also moved first: the KORU115 message now LEADS with the fix
(`write it qualified: *app/holder:Token`) instead of a rationale
("host types are bare only inside the module that declares them") whose subject
reads as a property of host types — the reading that produced the false rule
"host types are unnameable outside their module" where the compiler was only
asking for a spelling. The fix belongs in the message, not only the hint.

## What would correct this

A uniqueness-checked resolution that is provably order-insensitive (not
first-wins renamed), or a real cross-module shape that module-local bare cannot
express (the contract/companion merge already covers the known candidate).

Pins (referenced, not restated): 220_031 (bare refusal), 220_034 (qualified
spelling green), 220_037 (qualified ref to an undeclared type refused — KORU117),
220_038 (qualified ref to the wrong module refused — KORU117).

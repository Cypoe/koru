---
type: belief
id: frag-each-arm-stages-and-else-dispatch
provenance: ruled by Lars 2026-10-24 across the staged-comprehension session — `! each BINDING (when EXPR | { FIELDS })*`, `! else` as the exclusive continuation of an each group
ts: 2026-10-24
---

# `! each` arms are a staged comprehension; `! else` is their exclusive continuation (belief)

**The ruling (Lars, 2026-10-24): the `!` arm head is a fold — bind, then any
sequence of `when EXPR` filters and `{ FIELDS }` projections in text order.**
`! each i when i % 2 == 0 { double: i * 2 } when double > 4` is legal and
means filter, project, filter. `! each` arms stay parallel by default —
every matching arm fires — and `! else` continues a contiguous each/else
run as exclusive dispatch: it fires only when no earlier arm in the run did,
`! else when …` is else-if, bare `! else` is the residual.

## What the code cannot hold — the alternatives rejected, and why

**`where` was the admission keyword, and it dissolved.** The first design
paired `where` (pushable, admission-site filter) with `when` (engagement-site
guard). Chaining made the distinction positional: a `when` before any `{ }`
literally cannot reference produced names, so it IS admission by
construction — `where` would have been a second keyword marking what
position already marks. We chose `when` alone and dropped `where` rather
than keep a word that invites the reader to think it means something `when`
can't. If a producer-side specialization (e.g. `i % K == 0` → stride) ever
needs a promise it can pattern-match, position-before-`{ }` is that promise;
a keyword for it would be sugar, not semantics.

**Stages replace scope; they do not layer.** A `{ }` stage yields exactly
the names it lists — `! each i { double: i * 2 }` drops `i` unless it is
re-listed (`{ i, double: i * 2 }`). That is what makes `{ i: i + 1 }` a
legal rebind rather than a shadow: the old `i` is unreachable the moment
the stage closes, so two `i`s never coexist. The rejected alternative —
stage scopes accumulating — would have made every rebind a shadowing
dispute and needed a new rule; replacement made the existing
duplicate-LHS check the only name rule the construct needs.

**`:` is one grammar everywhere braces open: LHS binds, RHS evaluates in
the enclosing scope.** Must-pun fires only where a pun spelling exists —
`{ i: i }` refuses (`{ i }` already says it); `{ i: i + 1 }` is a
computation, `{ key: it.k }` a rename, `{ pos.x }` a path pun. The pun is
mandatory only when it is possible — an expression RHS is exempt because
there is nothing shorter to write.

**Exclusivity is opt-in, not the arm meaning.** The parallel default was
deliberate: `!` arms are handlers by birth, and handlers fire. `! else`
spells the ordered-dispatch choice in the surface — the reader sees
"exclusive" in the arm glyph before reading a single guard, instead of
inferring it from arm-ordering rules. The rejected alternative — making
`! each` itself first-match — would have hidden a semantic fork in
declaration order and changed what "multiple handlers" means for every
existing `!` arm.

## Open edges held honestly

One `{ }` stage per arm today — chained projections (`{ f } { g }`) are
refused pending the stage-list AST; guards at most one pre- and one
post-produce (`when c when c2` refused — write `and`). The else-group
lookup is the contiguous run of `each`/`else` effect arms; a `! else`
with no `! each` head fails with a compileError, not a silent group-guess.
Producer-side pushdown (turning a pre-`{ }` `when` into stride or index
work) is legal by the scope rule and unimplemented — it is the payoff the
grammar was shaped to allow, not a claim the emitter already keeps.

**Zig is the oracle; JS/C# are a known gap, not a supported second
lowering.** `control.targets.kz`'s `for|js`/`for|cs` templates render
only `effects["each"]`, and the telescoped else-guard lives in the Zig
splice — so `! else` on a non-Zig build drops its handlers silently
rather than refusing. The produce stage shares the gap: the splice-side
consts, rebind renames, and post-guard wrap exist only on the Zig emit
path. Closing it is a separate-session port of the same semantics to the
JS/CS emitters, measured against the Zig pins (320_179/180/181) — not
something the current tree claims to do.

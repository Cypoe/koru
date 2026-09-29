---
type: belief
id: frag-a-dedup-key-must-be-an-identity-not-a-spelling
provenance: `~import mylib` resolved to `<dir>`; the `mylib/index` import the compiler synthesizes for `~import mylib/helper` resolved to `<dir>/index.kz`. Dedup keyed on the resolved path, so one module was imported twice and every declaration in its index emitted twice. Found 2026-08-08 wiring orisha's pump seam; fixed and pinned as 110_030. Evolved 2026-09-29: the same fault, second shape — the phantom-discharge JOIN between a synthesized `std/store:taken!` literal and a parser-canonicalized `std.store:taken!`.
ts: 2026-09-29
---

# A comparison key must be an identity, not whichever spelling arrived

A dedup guard, a visited-set, a "does this obligation have a discharger" JOIN —
each is only as correct as the claim that two entries with different keys are
different things. When the key is a *spelling* rather than an *identity*, the
check is silently partial: it catches the pairs that happen to arrive spelled
the same and misses the ones that don't.

koruc's import loop guarded on the resolved path. A package imported as a
directory resolved to `<dir>`; the same package reached through its own index
file resolved to `<dir>/index.kz`. Two strings, one module — and the compiler
generates the second spelling itself, from the first, whenever a package's index
imports a sibling. So the guard could not have been more precisely wrong: the
one duplicate it was guaranteed to face was the one it could not see.

**A partial guard is worse than none, because it is a claim.** The debug log
printed `DEDUPLICATION: Skipping duplicate import` for every std module, in
volume, all correct. Reading that log builds the belief that dedup works. It
does — for the shape that happens to spell itself consistently.

The downstream damage is the part worth remembering. Nothing checked "one module
declaration per source file"; the emitter simply groups declarations by logical
name and writes them all into one struct. So a module that arrived twice put its
entire declaration surface in twice, and the failure surfaced as `duplicate
struct member name 'std'` — which reads as a submodule's host line colliding
with its parent's, an entirely different bug in an entirely different pass. **A
broken identity does not fail where it breaks; it fails wherever the duplicate
is finally noticed**, and it wears that layer's vocabulary.

## The second shape: the join

The dedup guard had one writer per spelling. The phantom-discharge match has
two: the parser canonicalizes the author's `std/store:!taken` to the internal
`std.store:!taken`, while `std/store`'s own transform *synthesized* the produced
tag as the literal `"std/store:taken!"` — the source spelling, written where the
parser never reaches. Both sides were "right": the parser canonicalized, the
transform minted a fully-qualified constant. The join still missed, and an
entity store's `take` could never find its discharger — reported as the
obligation being undischarged, again one layer's failure wearing another's
vocabulary (the four 690_STORE entity pins went red the moment the parser side
canonicalized; the latent divergence had been invisible while both sides
spelled the same wrong way).

That second instance sharpens the rule: **canonicalization is not a property of
a boundary, it is a property of every writer.** Canonicalizing at parse time
while a transform mints the raw spelling is the same partial guard — it only
looks complete because the two spellings had never been made to differ before.

Three rules fall out. **The key must be a canonical form**, computed by a
function that every construction site of the thing routes through — a source
spelling that never survives the parse boundary, and a canonical form that
everything downstream (checkers, joins, synthesized literals) is required to
emit. **Synthesized names must be minted in canonical form** — a transform
writing a name literal is a writer at the same boundary, not an exception to
it. And **the invariant should be enforced where it is depended on**, not only
where it is established: the emitter refusing a second module declaration for
a file it already emitted is the dedup-side instance; refusing the legacy
spelling at every qualified-name position (the KORU035 wall over call sites,
decl heads, transform heads and phantom qualifiers) is the join-side one —
it makes "the canonical form" the *only* form that can arrive.

Related: [[frag-a-check-that-cannot-match-reports-clean]] — same shape, a guard
whose key cannot match the thing it is meant to catch, reporting success.
And [[frag-synthesized-phantoms-are-derived-names]] — the adjacent claim that
constant synthesized phantoms are safe because fully qualified; qualification
was never the whole obligation — the qualifier has a canonical spelling too.

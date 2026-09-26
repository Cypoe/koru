---
type: belief
id: frag-dedup-is-lift-then-delete
provenance: first cluster of the first deslop census — the matchGlob triple vs glob_pattern_matcher.matchSegment
ts: 2026-09-20
---

# Dedup is lift-then-delete: the canonical copy may lag the clones (belief)

A clone cluster is not "N copies, pick a winner." The copies drift, and the
direction of drift is not always toward the module that looks like home.
When the deslop census (`tools/deslop.zig`) surfaced `matchGlob` duplicated
across `ast.zig`, `shape_checker.zig` and `transform_pass_runner.zig`, the
obvious move was to route all three to `glob_pattern_matcher.matchSegment` —
the wired, tested, documented canonical. Reading both bodies first caught
that the canonical is a **subset**: the stray copies support `*suffix` and
`prefix.*.suffix` (middle wildcard), and `matchSegment` returns false for
both. Picking the winner would have silently removed two wildcard forms from
the language's transform matching.

**The ruling.** Before deleting clone members, establish which member is the
semantic *superset* — not which sits in the nicest file. If the canonical
lags, lift its semantics up to the superset first, then delete the copies.
"Which copy is canonical?" is the wrong question; "which copy is the
superset?" is the right one, and it is a readable judgment over a closed
answer space — exactly the shape a System One adjudication layer answers.

**Same name is not same contract.** The census also surfaced a fourth
`matchGlob` in `runtime_registry.zig` with a different contract (prefix-plus-
separator, not wildcard forms). The fingerprint correctly kept it out of the
cluster; the name collision is its own slop class — the fix is a rename, not
a merge. Dedup tooling that groups by name would have proposed a false
merge.

**The liftable unit can be a prelude, not a function.** The second removal
(the `emitPrefixMatcher{Zig,C,Js}` triplet in `regex_engine.zig`) showed the
other half of the ruling: all three copies were *identical* — no laggard
canonical — yet the functions could not merge because their payloads are
target-vocabulary string literals. The census still hashes them equal
because literals fold to `STR`: the fingerprint measures the *skeleton*, and
in an emitter family the skeleton is the shared emit-time analysis (dead-sink
+ suffix-terminal scans). So the dedup boundary is not always "pick a
function"; it can be "lift the analysis prelude out of N target-specific
emission bodies" (`analyzePrefixDfa`). In emitter-heavy code the cluster's
removal unit is the part that is *not* strings.

**Drift hides in omitted fields.** In struct-literal clone families the
superset question has a second axis the fingerprint cannot measure. The
`ast_functional.zig` continuation clones split into two clusters by field
count: four `cloneContinuationWith*` sites spelled the same thirteen
fields and *omitted* `location` and `is_transformed_subtree`, so the
defaults took over — clones of a flagged graft lost their checker
exemption and pointed at `generated:0:0`. Those four hashed together as
one cluster; the complete fifteen-field version was a *different*
cluster. A uniformly deficient family can therefore outrank the correct
code it should delegate to, and the deficit is invisible in the present
fields — it lives in the fields nobody wrote. Field-set diffing ("what
does this literal leave to defaults?") belongs inside the superset
judgment, and the consolidated helper now owns the full field set so
future drift has no defaults to hide behind.

**Drift also hides in omitted switch cases, and a recursive fallback can
mask it.** The three `needs_binding` scans in
`emitSubflowContinuationsWithDepth` re-spelled a *subset* of
`bindingIsUsedInContinuations`'s node switch — `invocation` and
`branch_constructor`, but no `label_with_invocation`, `inline_body`, or
`assignment`. The gap was invisible because every site immediately fell
back to the full recursive check on *nested* continuations: the
deficiency only ever applied to the current level, and a binding
referenced one level down still resolved. The correct move was not a new
helper but extracting `stepReferencesBinding` from the existing
superset's own switch and routing all four sites through it. When a
clone site sits next to a recursive call into the fuller version, the
recursion is evidence the subset is wrong, not that it suffices.

**Vocabulary tables extend the ruling.** The "prelude, not function" case
had a next step it did not name: when the differing payload is *entirely*
string literals under identical control flow, a comptime vocabulary table
still lifts the skeleton once. The `emitPrefixMatcher{C,Js}` pair hashed
equal because literals fold to `STR` — and they were equal *because* the
control flow never differed, only decl keywords, `==`/`===`, sentinels,
and cast spellings. `PrefixVocab` parameterizes exactly those; the Zig
sibling, genuinely a different skeleton (range-for, `?usize`), stayed
separate. The line to draw is control flow, not "has strings": shared
flow + differing literals → vocab table; differing flow → separate
emitters. Emitted-output equivalence deserves a receipt — a scratch
harness diffed twelve emitted matchers byte-for-byte across the merge.

**The helper already exists.** Half of this family's dedup was not
extraction but *routing*: `cloneContinuationWithNodeAndContinuations` and
`cloneFlowWithContinuations` were already the shared tails, and later
authors re-inlined the literals at new sites instead of calling them.
Widening the existing mechanism (`?ast.Node` param, `mark_transformed`
flag) covered five more sites than building a new helper would have —
find-it-before-you-build-it applies inside a single file.

**A declared sole authority makes clones spec violations, not just slop.**
`annotation_parser.zig` comments its block tokenizer "the ONLY place that
[delimiter] knowledge lives… delimit through them, never with
indexOf/split" — and three parser sites still hand-rolled bracket-depth
scans plus `splitScalar('|')` for `[a|b]` blocks. The drift is not subtle:
the naive scans mis-delimit `doc("a|b")` and `custom(foo[1])`. When a
module declares exclusivity, a structural clone of its job is deficient by
construction — the superset question answers itself, and the fix is
routing through the declared mechanism (`collectBracketAnnotations` now
wraps `findBlockClose`/`splitEntries`), never writing a second scan.

**The .kz lane's removal unit is the alias, not the call site.** The
stdlib-slice fold (29 clones: `stripQuotes` ×11, `mkPathH` ×9,
`bareBorrow` ×2, kebab `isIdent*` ×7 across fifteen `store.*`/`grid.*`
parts) could not move call sites — the host fns live inside each part's
`H` struct and every call reads unqualified. The fold was a one-line
alias per site (`const stripQuotes =
@import("emitter_helpers").stripQuotes;`), preserving local names —
including `mkPathH2`, which kept its name while pointing at the
canonical body. In this lane "delete the clone" means "delete the body,
keep the spelling"; the alias IS the removal, and a census keyed on
bodies counts it clean while one keyed on names never will. The same
pass found a same-name decoy: `fieldOrder` in `store.insert.kz` calls
`storeInsertOrder`, in `store.stored.kz` calls `storeFieldOrder` —
skeleton-identical, contract-divergent. That decoy quarantined the whole
`storeRefs`/`storeRefsAll` family, since every member routes through
`fieldOrder`; a fold that started from the top-level clones would have
silently merged two different orderings. And the pre-existing canonical
`isIdentChar` was *not* the superset — it lacks `-`, the kebab
predicate's whole reason to exist — so the fold minted
`isKebabIdentChar` rather than routing into a deficient home.

**Open questions.** (1) Whether cluster ranking should prefer the superset
member as canonical anchor rather than the first member — the census cannot
yet order members by semantic coverage. (2) `copy count` is not `removal
payoff`: test-scaffolding clusters rank high while being better left
duplicated. The weight function wants a structural discount, or that is the
first honest job for the judgment layer behind the funnel. (3) The census
groups on present structure only; a field-count or field-name axis on the
fingerprint would surface deficient-literal clusters as one family instead
of two.

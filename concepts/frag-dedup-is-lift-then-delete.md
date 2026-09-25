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

**Open questions.** (1) Whether cluster ranking should prefer the superset
member as canonical anchor rather than the first member — the census cannot
yet order members by semantic coverage. (2) `copy count` is not `removal
payoff`: test-scaffolding clusters rank high while being better left
duplicated. The weight function wants a structural discount, or that is the
first honest job for the judgment layer behind the funnel.

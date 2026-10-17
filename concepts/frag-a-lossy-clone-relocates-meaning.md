---
type: belief
id: frag-a-lossy-clone-relocates-meaning
provenance: introduced on main — fix(ast): a cloned path keeps its module qualifier
ts: 2026-08-01
---

# A clone that drops a field does not copy less — it copies something ELSE (belief)

A desugar that replicates a node is making a claim: *this arm means the same
thing at every place I put it.* That claim is only as good as the clone. Drop a
field and the copy is not a partial node — it is a **different, complete node**
that the rest of the compiler will happily resolve, check and emit, because
nothing downstream can tell a lost field from one that was never set.

The instance that made this a belief: `clonePath` copied a path's segments and
not its `module_qualifier`. A choke body calling across a module arrived, at
every replicated stage, as a call into the CURRENT module — same segments, new
meaning. It then misresolved against a nearby local name, and the diagnostic
named a tor that appears nowhere in the source. Nothing was corrupt; the
compiler was reasoning correctly about the wrong program.

**Why this class hides so well.** A missing field has no representation. There
is no null to trip an assert, no shape mismatch, no arity error — an optional
qualifier is *validly* absent for every local call, which is most calls. So the
lossy clone is indistinguishable from a legitimate node until something
downstream needs the dropped field, and by then the evidence of the drop is
gone. The error surfaces far from the clone and describes a program the author
never wrote, which is exactly the profile of a bug that survives a corpus.

**What a corpus does not protect here.** Field-dropping is invisible until a
clone site meets a node that USES the field, so coverage of the *transform* is
not coverage of the *clone*. A homogeneous ladder that re-raises `| failed`
never puts a cross-module call in a replicated arm, so the point-free tests, the
metacircular self-compile and a published post all passed over this for weeks.
The provoking shape came from outside the tree — see
[[frag-pointfree-threads-the-branch-left]] on why heterogeneous ladders are the
representative case, not the exotic one.

**The ruling.** A clone helper is exhaustive by default, and a field it declines
to copy is a decision that must be written down where the copy happens.
`cloneContinuations` already does this correctly for two — `kind` and
`plain_value` each carry a comment naming the bug that would follow from
dropping them, and `condition_expr` is nulled deliberately. That is the standard;
silent omission is not.

**Open questions — revised.** (1) `cloneInvocation` is now exhaustive
(`variant`, `return_binding`, `return_destructure`, `annotations`, `marks`,
`inline_body`, `preamble_code`, `source_module`, tap flags all copy); the
warning it carried is discharged. (2) The wall now exists in a weaker but
measured form — `ast_functional_test` pins
`serializeCanon(cloneItem(x)) == serializeCanon(x)` per field class, so any
*serialized* field a clone drops is a test failure, not a latent bug. That
covers the canonical surface; what it still cannot see is a field the
serializer also skips — the structural-exhaustiveness wall (a field added to
the struct fails to compile until the clone decides) remains unwritten.

**Second instance, different detector.** The digest run found the class again
without any semantic misresolution: `transform_pass_runner.itemDigest`
fingerprints items through `serializeCanon`, so a dropped *serialized* field
shows up as an accounting lie rather than a wrong program — the same defect,
caught at the fingerprint instead of downstream. Eight field classes were
silently resetting to defaults: `ProcDecl.inline_flows`/`is_public`,
`ImmediateImpl.is_impl`, `EventTap.annotations` (allocated *empty*, not
null — the drop had a shape, just no content), `Arg.had_explicit_label`,
`Flow.super_shape`/`site_of`, `FacetField.alts`/`alt_default`, and
`inserted_by_tap`/`from_opaque_tap` on the `conditional_block` and
`metatype_binding` node payloads. Pointer-copied fields are a different
case: same pointer, same serialization, no digest drift — the aliasing
hazard is real but belongs to the ownership story, not this one.

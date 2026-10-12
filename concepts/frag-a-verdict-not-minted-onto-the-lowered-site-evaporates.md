---
type: belief
id: frag-a-verdict-not-minted-onto-the-lowered-site-evaporates
provenance: prepared-witness tranche 2026-10-12 — storedWriteNarrowing proved
  f32<-f64 at the write site and then *discarded* the proof, keeping only the
  refusal text; anything downstream had to re-derive the fact from emitted
  `__koru_store_*` text
ts: 2026-10-12
tags: [koru, verification, witnesses, marks, transforms, pcc]
---

# A verdict not minted onto the lowered site evaporates (belief)

A transform that checks a fact and then keeps only its refusal has produced
a verdict with zero reach. The check ran; the record did not. Every later
consumer — another pass, an emitter, an external checker — is left with the
survivor's choice: re-derive the fact from lowered text, or treat the site
as unchecked.

The narrowing wall made this visible. `storedWriteNarrowing` resolved the
destination column type and the proven RHS type per write — and returned a
`?[]const u8`: the diagnostic, or nothing. The proof existed for one call
frame and was gone. K3's "consume what the transform already had to produce"
was therefore an *assumption*: nothing was produced that outlived the
transform.

The mechanism that makes it a fact is already in the tree, and it is the
one the callsite-proofs draft recommends for the whole witness surface:

- **`.marks`** — `Invocation.marks`, `NamedBranch.marks`,
  `binding_marks`. Compiler-internal string lists, *never parsed from
  surface syntax*, so a witness is unauthorable by grammar: forging one
  requires compiler-internal access, which is exactly the forge-gate an
  N4-style battery wants to test.
- **Mint at the lowered site, not the surface call.** The `stored` block
  dissolves — what the emitters see is `__store_envwrite_*` /
  `__store_write_*` invocations. The mark rides those: the obligation site
  as it exists in the flow graph downstream consumes. The surface syntax's
  write cells are arg-text; the lowered call is the first node that *is*
  the obligation.
- **The verdict vocabulary covers what the solver could NOT prove.** A
  mark is `lossless | deferred | non-numeric | refused`. `deferred` is the
  important one: an unproven write previously vanished into the same
  silence as a proven one; now the gap is enumerable — a future `enforce`
  contract can refuse a program carrying unresolved marks.
- **The consumer must sit behind the transform pass.** `enforce` runs in
  Phase 2.5 `comptime_main`, which receives the post-transform AST, so the
  marks are simply there. The `witness` command dispatches on `seed_ast`
  before transforms run — its census cannot see marks without deeper
  plumbing, and printing them there would be a zero-row lie.

Rung-1 shape, landed: `storedWriteCheck` returns a `StoredWriteVerdict`
record (site, dest, src, narrows); `stored|zig` mints
`@witness("stored-write-numeric","bodies.x","f32<-f64","lossless")` onto
each lowered write call; `enforce` prints
`[witness] stored-write-numeric: lossless=… deferred=… non-numeric=… refused=…`
— one stable line, pinned by `expected_comptime.txt` (690_364), greppable
from `backend.err` as the verbatim record a Lean checker consumes.

## Rung 2: the receipt is re-decidable, and something re-decides it

A witness only earns the name once an independent checker can rule on it
from the mark alone. Two changes made that true:

- **The mark carries enough to re-decide.** A literal write mints
  `f32<-literal:0.1`, not `f32<-literal` — a checker given only the kind
  token could not tell `1.5` (exact in f32) from `0.1` (exact in neither
  float). The verdict set gained `rounds`: a decimal that no float of the
  column holds exactly. It is a recorded fact, not a refusal — refusal
  semantics did not move.
- **The checker shares no derivation with the solver.** The Zig side
  decides float exactness by the odd-part/bit-length formula over u128;
  `verify/k3/StoredWriteNumeric.lean` searches the format's whole exponent
  range for an exact `m·2^e` with unbounded naturals. Agreement between two
  derivations is evidence; agreement of one derivation with itself is not.
  Role A holds three soundness theorems (typed widening embeds the value
  set; a lossless int literal is in range; a lossless float literal has an
  exact representation in the format). Role B rules MATCH / MISMATCH /
  MALFORMED per site line; N4's forged corpus must be rejected line for
  line; an empty corpus FAILs.

The gate (`scripts/k3_witness_gate.sh`) was itself wrong on first draft:
`lean … | tail -1 || fail=1` takes `tail`'s exit status, so a failing
batch passed. A negative probe (corrupt one golden verdict, expect FAIL)
caught it. An oracle gate needs its own negative probe for the same reason
the harness's `*_REFUSES` legs did: a check that cannot fail looks exactly
like a check that passes.

## What follows

- K3 stops being a checker bolted on afterwards: the witness is data the
  solver already produced, not a reconstruction. A Lean conformance check
  reads the `[witness]` lines (or the marks directly, once a sidecar
  artifact lands) and rules on `{site, dest<-src, verdict}` triples.
- `refused` marks are minted but never survive — the program dies at the
  refusal. If a census of *would-have-refused* sites is ever wanted, the
  mint must precede the die, and the refusal path must thread the marks
  through the dead program.
- W1/W6 from `docs/koru-callsite-proofs-draft.md` now have a concrete
  instance: `.marks` with a `kind,site,d<-s,verdict` encoding is what the
  recommendation looks like in code. Lars's ruling can point at it.

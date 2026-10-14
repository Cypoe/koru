---
type: belief
id: frag-a-check-and-its-satisfier-must-enumerate-the-same-set
provenance: prose-check A regenerates through three generators; the status ceremony's regen step ran two. The by-example shards drifted from 2026-07-25 to 2026-08-08 while the check's own message blamed a hand-edit. Found and fixed 2026-08-08
ts: 2026-08-08
---

# A check and the routine that satisfies it must enumerate the same set

A gate that says "these artifacts must equal their regeneration" is paired,
always, with some routine that performs the regeneration. Two lists of what
"these artifacts" means — one in the checker, one in the publisher. Nothing
forces them to agree, and when they diverge the gate does not report a
divergence. It reports the *symptom* of one, in the vocabulary of whatever it
assumed the cause to be.

koruc's prose-check A regenerates through three generators before diffing. The
status ceremony's regen step ran two of them. So every ceremony faithfully
refreshed the corpus and the tutorial and left the by-example shards two weeks
stale, and the gate went red on a cadence nobody could attribute — because the
two generators that *were* run produce no diff, so the step looked like it was
working every single time it ran.

**The check's own message named the wrong cause, confidently, for two weeks**:
*"a generated artifact differs from its regeneration (hand-edited) — Never
hand-edit a generated file."* Nobody had hand-edited anything. The diff was
purely additive — new passing tests that no one had re-derived the corpus from.
A diagnosis baked into an error message is a hypothesis about why the check
failed, written before the failure existed, and it inherits none of the
evidence. Read as an instruction it sends you looking for an edit that isn't
there; the honest reading is "these differ", and the cause is yours to find.

Cost is measured in *elapsed* time, not effort. The actual repair was running one
command. It sat unfixed for a fortnight because the failure was legible enough to
categorise ("that gate, the pre-existing one") and misleading enough to not
reward a look. **A red that everyone has learned to describe is a red nobody has
read.**

The structural fix is not "remember to run the third generator." It is that the
two lists should be one list — the routine should ask the checker what it checks,
or both should read the same manifest. Until they do, the pairing is a
coincidence maintained by attention, and attention is exactly what a gate exists
to replace.

Related: [[frag-a-check-that-cannot-match-reports-clean]] — a guard whose key
cannot match reports success; this is its mirror, a guard whose *satisfier* is
narrower than the guard, so it reports failure forever and blames the wrong
thing.

## Evolve — the corpus itself is the second enumeration (2026-10-14)

The pass-graph witness arcs apply the fix, not just the diagnosis: the
backend commits a census line counting its own arcs — edges, orders,
transform edges, stage rows — and the Lean oracle re-counts the lines it
received. Two enumerations of "what the graph is," one in the emitter,
one in the oracle, and a dropped, duplicated, or invented arc unbalances
the corpus by count rather than by argument. The divergence-reporting
vocabulary is honest about it: GRAPH-VIOLATION names the count drift as
a corpus property, not a verdict mismatch on a line.

The same pattern was already running in transform-app-census and
descriptor-scope; the pass-graph rung makes it the *default shape* for a
check that wants an independent verdict: commit the inputs, commit the
count, let the oracle re-decide the rule. A checker that cannot state
its own enumeration cannot be checked this way — the census is the
contract, not a convenience.

A second, environmental instance surfaced in the same session: putting
Lean's elan toolchain dir on PATH ahead of the system dirs shadows
`cc`/`clang`/`ld.lld`, and `zig build`'s CRT discovery links the
bundled glibc-2.34 Scrt1.o — producing backend binaries that cannot exec
on this host (measured: `__libc_start_main@GLIBC_2.34` in verneed, on a
2.31 image). The oracle invocation that asked for verification *caused*
the artifact it meant to verify to be built differently — the path that
supplies the checker also perturbed the satisfier. `KORU_LEAN` exists
for exactly this; PATH mutation is the satisfier-side leak again.

The K4 receipt regime runs the discipline on identity: a signed receipt
is not an attestation unless the signer is in the pinned set
(`tools/attest.pub`). The verify path checks three claims separately —
signature valid (record untampered), signer trusted (the pinned
attester's did:key), digests match (the artifacts are the ones the
receipt names) — because each fails differently: a tampered verdict
breaks the signature, a stranger's key breaks the pin, a moved tree
breaks the digests. Collapsing them into "signature ok" would let a
forged-but-well-formed receipt ride a stranger's honest signature — the
same hole as a gate that only counted what it was shown.

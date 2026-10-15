# Koru verification gaps — what the battery does not cover

`koru-verification-path.md` describes what each layer checks. This doc
is the mirror: what each layer does **not** check, stated explicitly so
a "verified" claim has a visible boundary. Every gap is named; none is
silent. When a gap closes, delete its row — the doc is a ledger, not a
narrative.

Measured at `ccomp` `e94bfeeb9` (2026-10-14).

## K1 — CompCert on emitted C

- **The C lane only.** The zig emitter is the product lane and is
  unverified substrate — same elaborated flow graph, different
  translation arm. Source→emitter faithfulness rests on byte-diff,
  refusal honesty, and the test suite; no independent oracle reads it.
- **Upstream-of-oracle bugs.** ccomp validates compilation of the C it
  receives. If the C emitter mis-renders a construct, ccomp still
  compiles the wrong C correctly — the failure is above the oracle's
  view.
- **Refusal-defined fragment.** C-lane coverage is measured by named
  refusal classes (`C_REFUSES` pins, `c-lane-census.md`), not by a
  proved fragment boundary. A construct the census never classified is
  unaccounted, not unverifiable.

## K2 Use A — Alive2 congruence

- Intra-procedural optimization instances only. Whole-program pre/post
  IR congruence is not proven; the IR exposure itself is partial.

## K2 Use B — transform-app accounting

- **Digest honesty, not semantic congruence.** The `rm=`/`add=` lines
  prove the write-back touched the declared item multiset — not that
  the rewrite preserves meaning.
- **`preserves` bounds kinds, not content.** A transform may rewrite
  every item of a kind it declared preserved; the bound only refuses
  *collateral adds/removes* of held kinds.
- **`obliges` closes the first two decidable obligation claims, not
  semantics.** `kind-stable` and `matched-only` are shape-level:
  a transform may rewrite its matched items into anything and no
  obligation yet says the rewrite preserves meaning. The vocabulary
  is closed — extending it is a declaration surface, not an escape
  hatch; the semantic claim needs the §6a Lean kernel to have a
  domain at all.
- **Obligation granularity is the canonical digest.** An item a
  transform *clones but does not change* still registers as touched
  if the clone drifts the digest (observed on `module_decl`) — the
  obligation correctly refuses. Honest write-backs pass untouched
  items through by value; clone-drift fidelity in `ast_functional`
  is a real latent issue the obligation made visible, not a loophole.
- **Canonical digest equivalence is pinned, not proved.** The zig
  emitter and the Lean oracle agree on digests because the corpora
  match — a shared digest drift would pass both.

## Declared pass graph (rungs 1-3)

- **Opt-in coverage.** An unannotated pass carries no edges. Nothing
  counts what fraction of the pipeline is declared; the graph
  constrains only what declarers declared.
- **Order, not function.** The check validates declared edges against
  observed chains — it never judges whether a pass does what its name
  claims.
- **Corpus completeness rests on the emitter.** The Lean oracle
  re-decides the printed corpus; the wire between `validate()`'s
  summary and the printed lines is compiler code. The census makes a
  dropped arc inconsistent by count, but a backend that corrupts arcs
  and counts *consistently* is outside what the corpus can refute —
  that boundary is code review and the suite, not proof.
- **Two hand-written enumerations of one rule set.** The zig validator
  and the Lean checker mirror each other by hand; forged/drift corpora
  bound divergence but do not prove equivalence.
- **`collect` coverage tracks the AST.** Validation recurses into
  `module_decl` since rung 2 — a *new* `ast.Item` container kind would
  silently hide decls again, the way the seeded `compiler.kz` edges sat
  unvalidated for a full rung. No wall warns when the item vocabulary
  grows.

## K3 — Lean witness oracle

- Role A theorems cover the verdict definitions; the encoded *rules*
  are the specification. Lean re-decides the committed corpus — it
  cannot see what the backend never printed.
- The witness channel is `enforce`-gated by design: non-enforce runs
  produce no corpus, and the battery attests committed runs only.

## K3-adjacent — flow semantics kernel (`verify/semantics/`)

- **`FlowKernel.lean` is a model, not yet a consumer surface.** Its
  evaluator, fixtures, and metatheorems are kernel-checked, but nothing
  emits claims for it to re-decide — the corpus-facing leg
  (`graph-eval` witness lines on kernel-subset programs) is open, so
  the kernel currently verifies itself rather than any run.
- **No shared code with koruc.** Independence is the point — divergence
  between the kernel and the compiler is a bug in one of them — but
  until a surface consumes it, silent divergence on kernel-subset
  programs is possible in both directions and nothing would notice.
- **Kernel scope is declared small:** no effects, stores, labels, taps,
  transforms, modules, name resolution, or recursion. Programs outside
  the subset have no mechanized meaning.

## K4 — attested receipts

- **Rung 1 is self-attestation, not execution proof — but it is
  re-decidable.** The signed receipt records that the pinned battery
  ran on digested artifacts, signed by the attester the repo pins in
  `tools/attest.pub`. `verify --re-run` re-executes the recorded
  battery and compares verdicts, so the verifier confirms outcomes
  rather than trusting them; the signature then attests only
  provenance ("the pinned attester claims these inputs were tested").
  Without `--re-run` the verifier trusts the recorded verdicts — the
  residual is self-attestation for non-re-running readers. The
  `proof` field is reserved for the zk execution channel, which
  removes the attester's honesty from the trust base entirely
  (RISC-V guest — no toolchain yet).
- **The battery is two gates.** `attest.py`'s pinned list runs
  `witness_gate.sh` and `semantics_gate.sh`; the regression suite,
  ccomp oracle legs, and alive2 legs are outside the attested battery —
  widening the pinned list is the honest growth path, not a claim the
  suite is attested.
- **The attester key lives on one host.** `~/.agents/keys/` on the
  signing machine; a receipt from any other key verifies cryptographically
  but fails the trusted-signer pin — which is the intended refusal, and
  also means attestations cannot yet be issued from anywhere else.

## Cross-cutting

- Board snapshots and `test-results/` are evidence, not proof.
- Environment splits: node/dotnet absent on the WSL test image (js/cs
  legs unexercised there); ccomp resolves via `KORU_CC_ORACLE`; the
  backend binary cache salts on `ldd` output — a coarse ABI proxy.
- Toolchain PATH is part of the trusted environment: a toolchain dir
  that shadows `cc`/`clang`/`ld.lld` changes what `zig build` links
  (measured 2026-10-14: elan's bundled glibc-2.34 CRT produced
  un-runnable binaries on a 2.31 host). Oracle paths go through
  `KORU_*` env vars, never PATH mutation.

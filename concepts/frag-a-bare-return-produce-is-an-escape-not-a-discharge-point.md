---
type: belief
id: frag-a-bare-return-produce-is-an-escape-not-a-discharge-point
provenance: surfaced 2026-08-23 fixing 330_076/330_085 — auto_discharge_inserter read a subflow impl's bare-return produce as an "implicit terminator", appended the caller's disposer after its own `return r`, and emitted unreachable code naming an undeclared result. Evolved 2026-11-04: the escape now carries record-FIELD obligations across the produce boundary — the produce edge verifies the feed, the caller is seeded `res.<field>` debts. Evolved 2026-11-05: the chain-terminal produce (`x: _ -> h`) exits through validateNestedContinuations, not the leaf audit — and held bindings live outside `cleanup_obligations`, so even an audit that runs cannot see a held escape without a second pass over `bindings`.
ts: 2026-11-05
---

# A bare-return produce is an escape, not a discharge point (belief)

When a subflow impl whose event declares `-> T` ends an arm on a bare-return
produce (`| stop r -> r`), the produced value crosses to the CALLER carrying its
obligation. Linear transfer means the terminus settles nothing: the caller's
consuming site or the caller's own discharge owns it from there. An inserter that
reads the produce as "end of pipeline, obligations live, insert disposal" commits
two sins at once — a semantic one (double discharge: caller discharges what the
callee already freed) and a mechanical one (the disposal lands after the arm's
`return r;`, so Zig sees unreachable code naming an undeclared result).

The branch-constructor twin of this credit already existed
(`bindingEscapesViaBranchConstructor`: obligations on fields the constructor hands
back are removed from the cleanup set). The expression twin was missing because
`.expression` nodes are not `.terminal`/`.branch_constructor`, so the produce
fell into the void-chain "implicit terminator" case written for
`~acquire() | ok r |> print.ln(...)` — a case where nothing escapes and insertion
is correct. One classification serving two shapes, wrong for exactly the shape
with a declared return.

## The general shape

An obligation dies three ways: discharged, dropped (a wall fires), or **escaped**.
Every pass that decides between insertion and no-insertion must enumerate all
three. Escape is the easy one to forget because its evidence is negative — the
code says `return`, not `dispose` — and because the checker upstream models it
correctly, so no diagnostic ever points at the inserter. The failure surfaces
only as emitted garbage two passes later, which reads as an emitter bug.

## Open questions

- Whether label-jump args and other non-terminal exits need the same explicit
  escape credit (some exists for back edges after 330_076's earlier repair).
- Whether the emitter should refuse to emit any continuation after a producing
  return — defense in depth that would have turned this defect into a loud
  compile error instead of undeclared-identifier noise.

## Codegen twin — an escape the inserter cannot see still needs its marker (2026-10-05)

The same escape discipline applied again one layer down. Router-inlined arms
(`orisha:router`) are lowered to Zig by `continuation_codegen` BEFORE the
inserter runs, so an `allocated!` result bound and returned in a
Response-shaped produce (`|> X : b -> { body: b }`) escapes invisibly: no
discharge — correct — but also no `body_allocated` mark, because the mark
keyed on the producer's inline-body shape (`inlineBodyAllocates`) rather than
on the obligation the binding carries. The buffer leaked once per request,
silently, at exit 0 — the shape this frag's whole premise predicts: the
evidence of escape is negative. The mark now keys off the invoked tor's
`return_phantom`; `program_items` rides the codegen chain so the lookup
reaches the decl.

The free-half residue is recorded, not fixed here: an `allocated!` bind that
is neither returned nor switched on still has no discharge path on the
router-lowered arm — the inserter owns that decision and it never sees the
arm.

## The escape now carries record-field obligations (2026-11-04)

The original escape credited whole bindings. Record-field obligations
(`res.h` where `h: *Handle<owned!>`) died at the subflow boundary anyway —
the caller was seeded nothing, while the field still counted as a drop-debt,
so an explicit `dispose(res.h)` was refused as a phantom-state mismatch at
the CALL site (330_100 pinned the misdiagnosis; deadbolt frontier 1 named
the wall).

Three coordinated changes carry the obligation across:

- **The produce edge verifies the feed.** Packing a declared `<state!>`
  field from a dead or phantom-less binding refuses at the produce site
  with KORU030 (330_139/330_140) — the pack site is where the ledger can
  still see the truth, so that is where the wall lives.
- **The caller is seeded field debts.** `buildSubflowImplMap`'s whole
  exemption — subflow impls do not thread field obligations — is deleted;
  subflow-impl'd events seed `res.<field>` identically to direct calls.
- **The produce repacks.** `-> r` hands back a record repacked fieldwise
  into the CALLER's `Output` (its own frag) — the type boundary that used
  to be the second half of the same wall.

330_100 flipped MUST_ERROR → green; `dispose(res.h)` now pays the field
exactly as a direct call does (330_138 is the literal-produce twin).

## Two produce spellings slipped both walls (2026-10-15)

The 2026-11-04 repair verified the produce edge for the spellings it knew:
identifier paths and branch constructors on ordinary named arms. Probing
the fresh surface found two more ways to spell the same escape:

- **Label-fold produces.** `-> e` under `#L step(...)` was checked
  against an empty ledger — the inserter's arm-parent walk never
  resolved `label_with_invocation`, so `e.<field>` was never seeded.
  Pin 330_141.
- **Literal repack produces.** `-> { e.h, e.n }` was never decomposed
  for escape credit on either arm kind — the checker's plain_value
  branch didn't look inside record literals. Worse than a refusal bug:
  the hole was silent. Good repacks (330_143/144) and a peer-leak
  (330_142) all compiled unverified on main. The decompose is gated on
  the declared field carrying `!`, so literal produce of phantom-less
  fields stays free.

Same lesson one level wider: a pass that enumerates the ways an
obligation dies must enumerate arm SHAPES and produce SPELLINGS too —
each new spelling is a new place for the escape to hide.

## Two ledgers, and the audit only read one (2026-11-05)

The produce spellings above all concerned MINTED obligations — the set
`cleanup_obligations` tracks. Held obligations are seeded into `bindings`
with their `<state!>` marker and then deliberately cleared from
`cleanup_obligations` (the contract settles them invisibly, so the leak
audit must not chase them). Correct for exit-balance — and a blind spot
for escape: an audit that reads `cleanup_obligations` cannot tell "held
binding produced through a declared `!` return" (`issued`, custody
transfers) from "held binding produced through a bare return" (the debt
evaporates — same wall as a minted evaporation).

The chain-terminal `x: _ -> h` produce compounded it: that node exits
through `validateNestedContinuations`'s void path, which ran
`verifyProduceFieldFeeders` (does the pack feed the declared `!` fields?)
but never the escape audit, so even a MINTED `-> h` settled invisibly —
no `issued` edge, no refusal. The fix is one audit,
`auditProduceEscape`, shared by the `.expression` leaf and the
`.branch_constructor` chain exit, over two obligation sets: the tracked
set for minted, plus a `bindings` scan for held — named by the produce,
not disposed, carried → `issued`, not carried → KORU030, unnamed →
contract-open as before. 330_146's `fwd` relay pins held → borrow →
issued; 330_151 pins the bare-return refusal.

The standing asymmetry to keep straight: held obligations may end a flow
open (the host impl's contract settles them), so held joins the audit
only when the produce NAMES it — escape is opt-in per produce, never
ambient.

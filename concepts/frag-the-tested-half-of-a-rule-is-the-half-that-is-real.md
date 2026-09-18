---
type: belief
id: frag-the-tested-half-of-a-rule-is-the-half-that-is-real
provenance: 330_118 states a two-sided rule in its header and tests one side; the untested side turned out never to have been implemented, found 2026-08-07 by a Unikraft lift whose tor had the untested shape. Written after the same asymmetry showed up twice more the same day
ts: 2026-08-07
---

# The tested half of a rule is the half that is real

`330_118_conserving_tor_is_not_a_disposal_candidate` states a rule with two
sides. A tor that *conserves* an obligation — every arm hands back what it was
given — is not a disposal candidate. A tor that *converts* it "is a different
thing and stays a legitimate candidate."

The test exercises the first side. Its `step` conserves on every arm and is
correctly excluded, and it has been green for as long as it has existed.

The second side was never implemented. `eventReIssuesObligation` — which exists
twice, independently, in the checker and in the auto-discharge inserter — walks
every branch and returns *excluded* on the first arm that conserves, without
ever asking whether another arm converts. A tor that conserves on one arm and
converts on another is dropped from the candidate list entirely, and the caller
is told no tor accepts the state while calling the arm that accepts it. Pinned
red as 330_133.

**The comment reads exactly like a specification and enforces nothing.** It sits
inside a green test, in the file that is supposed to be ground truth, next to a
rule that *is* enforced — which is what makes it convincing. Anyone reading
330_118 to learn the rule learns both halves and has no way to tell that only
one of them is load-bearing.

So the general form: **prose in a test describes; only the assertion decides.**
Where a rule has cases, each case is real exactly to the extent some test takes
it. A two-sided rule with a one-sided test is a one-sided rule wearing a
two-sided description, and the undertested side will be wrong *by default*
rather than by accident — nothing was ever pushing it toward correct.

**The tell is countable and worth looking for deliberately: a test whose header
states more cases than its body exercises.** That gap is where implementations
drift, because there is no force on the unexercised side at all. It is not that
someone made a mistake; it is that nothing could have caught one.

And the corollary for writing rules down: when a rule has an exception, the
exception needs its own test *at the moment the rule gets one*, or the exception
is decoration. Stating both halves and testing one is worse than stating only
the half you tested — it manufactures confidence in the half that has none.

Related: [[frag-a-record-nothing-re-reads-becomes-a-fossil-that-gives-orders]]
— the sibling failure. There a record was true and went stale; here it was never
enforced at all. Both are claims nothing executes, and both read as authority.

## The same asymmetry in CODE PATHS, not just rule statements

2026-08-07, twice in one session, both found by pushing a real program through
the compiler rather than by reading it:

- A `->` produce lowering existed for bare-return tors and had **no counterpart**
  for tors with named branches, so a flow could only ever implement the former.
  Every flow-impl test in the suite produces a bare value — the untested case was
  the missing one. Fixed and pinned as 350_017.
- `rewriteModToBare` was called on **three of four** variant-emission paths. The
  fourth — the one an effect-bearing tor takes — shipped `$mod.` verbatim into
  the emitted Zig. Fixed; the pin (370_010) is red on a further defect.

So the form generalises past prose: **where a behaviour is implemented once per
path, it is real only on the paths some test walks.** N-of-M coverage does not
average out; the unwalked path is not "slightly less correct", it is arbitrary,
because nothing was ever pushing it anywhere.

**The countable tell, restated for code:** grep the helper, count its call sites,
and compare against the number of paths that structurally need it. Three of four
looks like thoroughness and is the exact signature of the bug. The healthy
version of "we do X everywhere" is a single chokepoint, not four call sites that
agree today.

And the sharpest instance: a *diagnostic* is the untested path par excellence —
see [[frag-a-diagnostics-hint-is-a-claim-not-a-tested-path]], where the hint
named a spelling no test compiled, and following the compiler's own advice was
the way into the bug.

## The same asymmetry in a REFUSAL, not a rule

Measured 2026-09-18, corrected same day: `parser.zig` enforces "the body must
follow `|>` on the same line" — the refusal of a dangling `|>` — only where a
test walks. Branch position enforces it cleanly: `| ok x |>` + body-below is
`PARSE001` (210_066). `=` bodies enforce it by accident: the orphaned next
line is blamed as `KORU010`. At flow head nothing enforces it at all —
`mail(): m |>` silently swallows the operator, parses a chain of one step, and
the *next* line becomes a separate flow, surfacing as `KORU100 unused binding
'm'` — a diagnostic true of the tree built and false of the program written.

The first measurement read this as a chain-stitching gap ("the ONE-rule
invariant was only taught at `=` bodies") and pinned `mail(): m |>` +
next-line step as a MUST_RUN. That framing was never right: `210_208` already
pins the legal multi-line form — leading `|>` lines — green at this same
position, and it compiles today. The operator *ending* a line is not a
continuation marker anywhere in the grammar; the stale nbody benchmark
(`kernel_pairwise.kz`) is written assuming it is and refuses today. The gap is
in the *refusal's* enumeration, not the chain's. Pinned as `210_238` with
MUST_ERROR expecting the `must follow '|>'` diagnostic — and the fix landed
the same day: two empty-segment drops, one in the inline-chain extractor, one
in `parsePipelineSteps`'s tail, now refuse `PARSE001` in every position the
splitter serves. `210_238` is green.

So the sharpest form yet: **a refusal is a rule too, and it is real only where
it fires.** A diagnostic enforced in one parse position and absent in the
sibling position does not fail as a missing error — it fails as a *wrong tree*
that downstream checkers then describe faithfully, one indirection away from
the fault. The missing refusal is worse than a missing feature: the feature's
absence is loud, the refusal's absence borrows another checker's voice.

Same enumeration-gap signature as the head-label sugar
([[frag-the-head-label-sugar-stops-at-the-subflow-body]]) — and note the prior
version of this section, committed hours earlier, asserted the gap lived in
the stitching. It was corrected by compiling the sibling positions, not by
reading them.

## The emitter had the same shape, plus a false claim to keep it company

The label/fold emitter has two paths: a specialized pre-label loop and the
general mid-chain one. The general path marks purely looping branches
`.arm => unreachable` in the post-loop switch, because the `while` consumed
them. The pre-label path carried a comment instead — *"Zig 0.15+ knows this
and considers the switch exhaustive"* — and emitted nothing. Measured
2026-09-18, on a fold whose subflow impl yields `| again | done` union
outputs: Zig does not narrow a `union(enum)` through a while condition; the
emitted switch refused `switch must handle all possibilities`. A claim about
a compiler's semantics, asserted in a comment, never compiled — the untested
half, one indirection deeper: this time the prose was inside the source.
`243_fold_subflow_union_outputs` pins it green.

## The same asymmetry in a KEY SPACE, not a code path

Measured and fixed 2026-09-18: label state vars are keyed by ARG NAME —
`<label>_<name>` — and nothing validated that a `#label` call's or `@label`
jump's args named fields of the target event. The one pinned fold
(`round(a.text, a.rounds)` → `@loop(a.text, a.rounds)`) used names that
happened to be fields, so the convention looked safe. Outside it, three raw
Zig errors: a bare arg whose leaf was no field emitted `loop_<name>`
undeclared; a wrong label (`bogus: a`) emitted `loop_bogus`; an under-filled
jump emitted a partial re-call (`missing struct field`). The key space had a
tested half — real field names — and the untested half was the entire failure
mode, surfacing one indirection away from the fault at stage-D.

`244_label_jump_rejects_unknown_param` pins the refusal: KORU043 names the
arg and the event at the checker, before emission. `245_label_jump_partial_
reseed_carries_over` pins the rule's other half, which was also unwritten:
an omitted param is not missing — it carries over, which is what the state
vars are `var` for (`@label` with no args is the empty-mask case and was
already legal). A jump's arg list is a re-seed MASK, not a call signature;
the checker now guards the mask's keys and the emitter honours its
omissions — `var` only on fields a jump actually names.

## 2026-09-18 — the pattern holds above the suite

Same asymmetry one level up, in a doc instead of a test: the blogpost skill's
title rule ("title leads with the subject by name", Lars-ruled 2026-07-15)
was prose in a skill file, and a draft post shipped the title the rule exists
to kill — "The Judge Is a Phantom Type", a verdict naming no subject. Nothing
had ever pushed an agent toward compliance: the publication gate checked
`draft:` and `date:` but never read the title, so the unexercised rule was
wrong by default, not by accident — the concept's own prediction, repeated in
a new medium. The rule has its tested half now: `check:publication` refuses a
staged title whose lead does not equal a declared `subject:` field, on the
mechanical tier — no override forgives it. Prose describes; only the
mechanism decides — in a skill file exactly as in a test header.

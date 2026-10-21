---
type: belief
id: frag-an-uncovered-symbol-names-three-different-things
provenance: 2026-08-06 — "variant coverage is a good find, we should try to encode it as tests" sent five agents at 15 uncovered emitter symbols; only 7 wanted a test, and 6 named defects
ts: 2026-10-21
---

# A coverage instrument's "uncovered" is a question with three answers, and only one of them is "write a test" (belief)

`check_variant_coverage.py` derives every `__`-prefixed symbol the stdlib
emitters can write and reports the ones no test's emitted output carries. Its own
docstring states the reading: *"a variant no test ever produces is invisible
surface: it ships, a green board says nothing about it, and the first execution
it ever gets is a user's."* That framing is about the CORPUS — it says the tests
are missing. The instruction it invites is "go write the tests."

Measured across all 15 it was reporting, that reading was right for **fewer than
half**:

- **7 were genuine corpus gaps.** A program exercising the path existed or could
  be written, and the symbol appeared in its artifact. These are the case the
  instrument's prose describes.
- **2 were substitution sentinels** — names the emitter writes into an
  intermediate template and then replaces before anything reaches an artifact.
  No program can ever carry them. The honest disposition is an exemption, and
  there were already accepted exemptions of exactly this species to pattern-match
  against.
- **6 named DEFECTS.** Not untested surface — surface that cannot run. One
  stdlib entry point has no declared branches, so the stdlib's own documented
  consumption form is refused and four symbols behind it are reachable only from
  a program that does not compile. Two transforms abort with a host panic on an
  ordinary user mistake. One whole pass generates its output and then discards it
  because a replacement check compares pointers captured in two separate
  by-value loops.

So the verdict "no test produces this" is ambiguous across a corpus gap, an
unwitnessable sentinel, and broken code — and the instrument cannot tell them
apart, because all three produce the identical absence.

## The rule this gives

**Read an uncovered symbol as a question — "why has nothing produced this?" —
never as an instruction to produce it.** Answer it by trying to reach the path
before writing anything. Which of the three you are in is usually established by
the first honest attempt, and the attempt is cheap.

**The dangerous response is the diligent-looking one.** Given "encode it as
tests", the obedient move is to make each symbol appear in some artifact, and for
the six defect cases a test can be *contrived* — a bare call site with no
continuation, a coordinator reordered to reach a dead pass. Those tests would go
green, the wall would go quiet, and three real defects would be sealed behind
coverage. A test written to satisfy an instrument rather than to pin a behaviour
is worse than the uncovered symbol it replaces, because the symbol was at least
still asking.

**An exemption is a ruling and it must not absorb a defect.** "No test can
witness this because the code always crashes" satisfies the letter of an
exemption's requirement — no test on this host CAN witness it — while inverting
its purpose, which is to record understood-and-accepted invisibility. Two of the
six arrived as proposed exemptions with genuinely strong evidence, and both were
refused for this reason: the evidence proved unreachability and unreachability
was the finding, not the excuse. A wall that has been taught to stop asking about
a crash has been converted from an instrument into a certificate.

**Where the answer is a defect, the residue is a failing pin, not an exemption
and not a fix.** Each of the six got an aspirational red naming the mechanism,
and the symbol stays uncovered. The pin and the coverage then close together:
when the defect is fixed, the same program that proves the fix becomes the
symbol's witness. That coupling is worth designing for deliberately — it is what
stops the two from drifting.

## What this says about instruments generally

The instrument was built to answer "is this surface exercised?" and was
*measured* answering "is this surface alive?" — a strictly more valuable question
it does not know it is answering. Its prose reads as though absence implies a
missing test, and for the majority of its findings the absence implied missing
reachability instead.

Worth carrying to the next coverage-shaped wall: **the null result of a
liveness-adjacent check is the interesting output**, and the check's own
description of what its null result means is written by someone who has not yet
run it against a real corpus. Read the finding, not the framing.

Related: `frag-a-corpus-exercises-its-authors-idioms` (a corpus is silent about
spellings its authors never wrote — the corpus-gap species above, from the
corpus's side); `frag-a-dead-attempt-standing-beside-a-live-system-multiplies-it`
(one of the six was a second, uncalled copy of a live function, and the same
audit found its sibling in the stdlib's build defaults);
`frag-a-check-that-cannot-match-reports-clean` (the failure mode this instrument
already defends against, by refusing to judge below a 50% artifact bar).

## Second audit (2026-10-21)

The split held on a second, larger run: 28 uncovered symbols broke down as
2 corpus gaps, 26 unwitnessable-by-construction (8 CS-target, 5 JS-target,
8 comment-carried or `_event`-suffixed markers, 1 data sentinel, 1
substitution marker, 2 dead-union arms, 1 panic-gated) — and the corpus-gap
witness itself caught a live
defect. `642_004`, the test written to witness `__rst{}`, was the first
execution of the raw-leaf emit path anywhere, and it failed: the emitted
`__jskip(s, p, e)` call was one argument short of the 4-ary signature every
sibling uses. The instrument's own docstring prophecy, verbatim — *"the
first execution it ever gets is a user's"* — except the witness test took
the bullet instead. So the three answers are not exclusive: a symbol can be
a corpus gap AND a defect, and the honest witness test is the cheapest
oracle for the second. Pinned: 642_004 (fix landed), 460_010 (clean gap),
620_020 (aspirational red — the `__BlkResult`/`__LnResult` dead unions'
unbound-bind path leaks a raw Zig type error where a refusal belongs; the
exemption names the defect, the pin holds the ruling).

Two readings of the same audit for the next auditor: exemptions for
non-Zig-target symbols must name the target and why it lands outside this
check's artifact scan (`|js` → output_emitted.js, `|cs` → output_emitted.cs),
and "emitted only into a comment or an `_event`-suffixed name" is a real
third species of unwitnessable — the marker names an AST object, not emitted
text.

Open: whether the other two checks in `invariants/checks/` carry the same
ambiguity in their own null results. Not examined, and the question only occurred
to me after the split came back 7/2/6.

## A dead-union exemption is a debt entry, not a resting place (2026-10-21)

The `__BlkResult`/`__LnResult` rows were ruled "dead/uncompilable — no
PASSING program can carry it" and exempted. Same-day correction: the
exemption was a *ruling waiting for its fix*. Once `KORU180` refused the
unbound sites, the symbols stopped existing — the allow rows came off
entirely (stale-by-deletion), and 401 derived symbols became 399.

So the classification has a fourth reading: **"unwitnessable because
uncompilable" is not an exemption class, it's a defect the wall has
already localized.** The dead union was invisible surface the instrument
correctly named — the exemption bought the ruling time, the refusal made
the exemption itself obsolete. The remaining "dead path" rows should be
read as prioritized defect debt, not as settled.

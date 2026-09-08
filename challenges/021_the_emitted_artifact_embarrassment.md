---
challenge: emitted-artifact-embarrassment
kind: frame
status: standing
yields: one verified embarrassment in a produced artifact (emitted source, binary, benchmark), pinned by the test that should have caught it
family: emitter
created: 2026-09-08
---

*Walker context — the recurrence that earned this frame. On 2026-09-08, one
session read the emitted artifact for Hello World and found **eight
embarrassments in one 870-line file**:*

```
- the leak audit (counter + check + failure strings) ships in every binary,
  including ReleaseFast — and the benchmark suite runs --release=fast, so
  published numbers were measured with the audit in the hot path
- 88% of output_emitted.zig (744 of 870 lines) is the stdlib surface —
  compiler machinery that already ran, dead in the source, stripped by Zig,
  duplicated 1,253 times across the tree (~112 MB)
- the JS interpolation engine rides inside a Zig build's output
- a `while` chunk loop in the print writer where the trip count was knowable
  (violates the repo's own emit-for-never-while rule)
- the same program emitted two different const blocks (`@as(i32, 42)` +
  `//@koru:inline_stmt` vs `const count: i32 = 42;`)
- a 64 KB stack buffer reserved per print call
- `compiler_env.zig` in a Zig test dir declaring `lang = "js"`
- `refAllDeclsRecursive` forcing full analysis of the residue under unit runs
```

***The suite carried 1,253 emitted artifacts that day and none of them were read.***
*Every board run produces these files; nobody looks at them. The board mines what
is red. `018` mines the green from the user's side — the CLI surface, the
diagnostic, the overclaim. This frame mines the green from the machine's side:
**what the compiler SHIPS, not what it prints.***

*One session, one file, eight findings. That is recurrence, measured.*

---

## The brief (sealed — you are the contestant)

**Open a produced artifact cold and read it as a professional who has to show
it to someone.** Not for correctness — the tests judge that. For *embarrassment*:
what would you be ashamed to see when you open this file, this binary, this
benchmark line?

An artifact is one of: `output_emitted.zig`, `backend_output_emitted.zig`, a
built binary (`a.out`, a unikernel image), a benchmark run, a `compiler_env.zig`.

**Pick artifacts without preselecting.** Compile a program you have not read the
output of before, or open one at random. If you know what you expect to find
before you open the file, you are auditing your memory, not the artifact.

Return **3–6 findings**. A finding on an artifact that *works* — output correct,
binary green — is worth more than one on a broken path, because the broken
paths already have frames aimed at them.

## The finding class this frame wants

Rank by this ladder. The top of it is where the session's best findings lived:

1. **Something in a shipped binary that has no business being there.** The leak
   audit in ReleaseFast. A debugger's exit-condition bookkeeping in a product.
   Highest class: it reaches the customer.
2. **Benchmark integrity.** Numbers measured with machinery that is not the
   language — the audit counter in an alloc-bound hot path, a debug flag left
   in a published figure. The number is the artifact.
3. **Dead source that reads as live machinery.** Residue that misleads the next
   reader into believing the transform runs in the program. The file *lies about
   what the program is*.
4. **The emitted artifact contradicting itself or its neighbors.** Two tests emit
   the same shape differently; a generated file declares a language it is not
   written in; an import that only exists to be stripped.
5. **Performance-rule violations in emitted code.** A counted loop emitted as
   `while` where the end was knowable; a per-call stack reservation that could
   be shared; work the optimizer must undo rather than never do.
6. **Stale comment cargo frozen into artifacts.** Rulings, pin citations, and
   prose duplicated hundreds of times at compile time — each one a lie waiting
   for the source to move.

## Ground yourself FIRST

**Measure before you claim.** An artifact is a snapshot of a tree at a moment.
Check the mtime before you read it, and check it against the compiler that
produced it — a stale artifact is the frame's number-one false finding (measured
2026-09-08: benchmark binaries from Aug 25 predated the leak counter; a
"finding" against them would have been fiction).

**Verify this session.** A finding you did not confirm against the current tree
is not a finding — it is narration. Cite the file and the lines. `unmeasured`
is not a finding.

**Compile, then read.** The suite's artifacts are free — every test dir holds
them. But a hand compile of a program you wrote tells you more than a corpus
file written by someone who knew the answer.

**A finding is the pin, not the observation.** For every confirmed finding, the
deliverable is the regression test (or the commit) that would have caught it,
and an honest answer to *why the board did not*. Name the category of blindness
— "no test reads the emitted artifact" is a category; "this test was missing"
is not.

## ⚖️ Make a qualified guess, never a verdict

Same stance as `002` and `018`. Two readings, and they are not yours to choose
between:

- **(A) the artifact is wrong** — a real wart, a lie, an embarrassment.
- **(B) it is deliberate** — a ruling, a measured trade-off, a cost accepted.

Write **both** in full, then lean with a confidence set by evidence: `grounded`
(you cite the artifact itself, a passing test, a ruling in the source) is the
only level where a hard lean is allowed; `inferred` is reasoning without a
citation; `unsettled` is a frontier. A 50/50 shrug is forbidden.

⛔ **Do not reroute the design to silence the finding.** "The file is ugly" is
not license to restructure the emitter around a bug you did not find. If the
finding is that the emission model ships residue, the fix is in the emission
model — not a comment explaining why residue is fine.

## Two live leads, already known, not yet diagnosed

- **The sweep's take analysis is program-wide and unverified.** Any `take` on a
  store anywhere makes every query of it emit the tolerant `while` loop; the
  emitter never checks that a body's take addresses its own cursor. The pinned
  contract (`690_031`) is current-row take only; the emitted loop is only exact
  under that assumption, and the fast `for` is lost where it is provable. This
  is a task, not this frame's job — this frame's job is the *embarrassment*:
  a store with one unrelated take emits slow loops on every query, and nothing
  tells you.
- **The whole emitted file.** The 88% residue is the flagship. Nobody has
  decided whether `output_emitted.zig` should read like the program.

## What "done" looks like

- 3–6 findings, each with the artifact, the file, the lines, and what an
  embarrassed professional would say.
- For each: both readings, a qualified lean, a confidence with its grounds.
- For each confirmed one: the pin or the fix, and the **category of blindness**
  that let it through.
- Findings on **working artifacts** counted separately from findings on broken
  ones. If every finding came from something already failing, this frame did not
  run.
- No unverified claim. Every number cited was measured this session.

## Failure modes

- **Reading a stale artifact.** Check the mtime. The tree moved; the artifact
  did not.
- **Hunting in the compiler source instead of the artifact.** The wart you are
  hunting is what *ships*, not what the emitter code looks like on paper.
- **Narrating instead of pinning.** An observation with no test and no commit is
  a comment.
- **Fixing the design instead of the wart.** The fix is in the emission model,
  not in the prose around it.
- **Only finding red things.** Three other frames already do that. Mine the
  green — the artifacts that pass, and are still embarrassing.

---
challenge: tightening
kind: frame
status: standing
yields: one program koruc accepts and must not, refused in the compiler — a red-then-green MUST_ERROR pin, a fix in src/, and a legal sibling that still compiles
family: correctness
created: 2026-09-24
---

*Walker context — the recurrence that earned this frame. Since 2026-08-01,
**42 of 1078 commit subjects** are a refusal the compiler did not have: a
dangling `|>` swallowed in two of three parse positions (`458c0e54e`), label
args naming no field (`b8532f278`), a second index declaration on one store
(`084904cdd`), call-shaped `=>` constructions reaching Zig as garbage
(`194ca102d`), empty-path `|variant` invocations panicking (`8b8a614bb`),
duplicate call labels (`9ba003f18`). Every one was found **by accident**, while
doing something else. No frame hunts for them.*

*`010` audits refusals the suite already pins. `018` mines paths that work for
odd output. `023` reads diagnostics that already fire. This frame hunts the
program nobody pinned: **the one the compiler lets through.** A missing feature
disappoints; a missing refusal lies — the author's program compiles, and the
language's promise quietly isn't kept.*

*The concept behind the method: `concepts/frag-the-tested-half-of-a-rule-is-the-half-that-is-real`
— a refusal enforced in one position and absent in its sibling fails as a wrong
tree some later checker describes faithfully.*

---

## The brief (sealed — you are the contestant)

**Find a program `koruc` accepts and must not. Make the compiler refuse it.**

Return **1–3 tightenings**, each landed as its own commit:

1. a `MUST_ERROR` regression test with its `expected_error.txt`, which you ran
   **red at HEAD** (the compiler accepted it — quote what it did instead);
2. the fix in `src/` (or `koru_std/`) that makes it refuse, **at Koru level**,
   with a diagnostic code and a caret on the text the author wrote;
3. a **legal sibling** — the nearest program that must still compile — run
   green before and after, so the tightening provably did not over-refuse.

A tightening you found but did not land is a lead, not a deliverable. Report it
under leads with its repro.

## The ladder — what a missing refusal costs

Rank by where the accepted program ends up. Higher is worse, and worth more:

1. **Accepted and runs wrong.** It compiles, runs, and does something the
   author did not write — a fabricated value, a dropped step, a silent default,
   an obligation that never discharged. Nothing downstream can tell.
2. **Accepted, then the author is blamed for something else.** The bad text
   parses into a wrong tree and a later checker describes that tree faithfully
   — `KORU100` on a binding the author did use, `KORU010` on an orphan the
   author never made (`458c0e54e`).
3. **Accepted by the frontend, dies in the backend.** The Zig compiler, not
   Koru, rejects it: host-level noise, emitted-file paths, symbols the author
   never wrote (`194ca102d`). The refusal belongs in Koru.
4. **Compiler panic** instead of a diagnostic (`8b8a614bb`).
5. **Accepted and meaningless.** A no-op that looks like it does something — a
   bare `_` body on an optional branch (`943eab3f5`), a duplicate label, a
   declaration that names nothing (`220bb8a52`).

## Where the findings are

**Difference existing refusals against their siblings.** This is the method,
and the recurrence says it works. Every refusal in the compiler was written at
one site for the case someone hit. Take a refusal that exists — a `MUST_ERROR`
test, a diagnostic emission in `src/` — and move the refused construct:

- into a **sibling syntactic position** (branch arm ↔ inline chain ↔ subflow
  body ↔ pipeline tail ↔ `=` body);
- **inside a module** instead of the main file, or across a module boundary;
- into **comptime**, a **transform**, an **effect branch**, a **label loop**;
- onto a **sibling construct** the same rule logically covers (store ↔ grid,
  one index ↔ another std surface, a field ↔ a label ↔ a capture).

Then compile it. If the sibling position accepts what the original refuses,
that is a candidate.

**Mutate a passing test by one token.** Take a green positive test, make one
edit that should make it illegal — a duplicate, an omission, a wrong-kind
argument, a name that does not resolve, a second declaration — and compile.

**Read the diagnostic registry for codes with a single emission site.** A code
that fires from one place is a rule enforced in one position. Find the registry
before you count — do not grep your way to a number the registry disagrees with.

## ⚖️ The ruling must be grounded — you do not make language rules

This is the hard edge of the frame. **"It feels like this should be refused" is
not a finding.** Tightening on taste is inventing language — a refusal is a
rule, and rules are Lars's.

A candidate becomes a tightening only when a refusal is **grounded** by one of:

- a **passing `MUST_ERROR` sibling** that refuses the same thing in another
  position (the strongest ground — the rule already exists, it is just
  incomplete);
- a **stated law** in the compiler's own source, a concept file, or a test
  header that a passing test exercises (e.g. the pun law, one-binding-per-name);
- the program **cannot mean anything** — it reaches the backend as garbage, or
  panics, or its behavior depends on emission accident (ladder 3–4 are
  self-grounding: a Zig error or a panic is never the intended refusal).

Everything else is a **ruling question**. Write it down — the program, what it
does today, why you think it should refuse, the evidence — and do not land it.
It is a deliverable, not a failure.

For every tightening, write **both readings**: (A) the compiler is too loose;
(B) the program is legal and you misread the language. Lean with a confidence:
`grounded` cites one of the three grounds above and is the only level at which
you may land a refusal.

⛔ **Do not invent Koru syntax.** Your repro programs use only spellings a
passing test uses. If you cannot write the program without a guess, it is not a
repro.

## Ground yourself FIRST

- Load the `koru-toolchain` skill. Compile before you theorize.
- **Every accepted claim is compiled this session.** A test header that says
  "this compiles" is a comment. `koruc <file>` and the run are the evidence.
- Survey before you pin: search `tests/regression/` for the construct. If a
  `MUST_ERROR` already pins your program (red or green), you are in `010`'s
  territory — note it and move on.
- Run `git log --format='%h %s' -i --grep=refuse` and read the last month of
  tightenings. Do not re-find one that landed.

## Suite and tree rules — binding

- **Before any `zig build` or any edit under `src/` or `koru_std/`:**
  `pgrep -fl "run_regression|zig build"`. If a suite is live anywhere, stop and
  report — `/usr/local/lib/koru/src` symlinks the main checkout, so a worktree
  does not protect a live board from your edits.
- Filtered runs only: `./run_regression.sh <full_name> <full_name> ...`. Check
  the `Running N tests` line against the number you asked for — a misspelled
  name is dropped silently.
- Restore `test-results/unit-tests.json` before committing.
- Controls for every fix: your new pin, its legal sibling, every existing test
  that exercises the code path you edited (find them — the diagnostic code and
  the construct are the search terms), and `zig build test`.
- **Scope stop:** a fix that touches more than three files, or changes
  `src/ast.zig` or `build.zig`, stops at the red pin — report the scope, do not
  land it.
- Commit hooks require `## World Model` and `## Membrane` sections. Read a
  recent refusal commit (`458c0e54e`) for the shape. `--no-verify` is banned.

## What "done" looks like

- 1–3 tightenings, each a commit: red-at-HEAD pin (with what the compiler did
  instead, quoted), fix, legal sibling green, controls listed with their
  results.
- For each: its rung on the ladder, the ground that licenses the refusal, both
  readings.
- For each: **which existing refusal it is the missing sibling of**, or why it
  is not one. If two of your tightenings are one missing enumeration, that is
  the finding and it outranks both.
- Leads: candidates you compiled and did not land, with repro and reason.
- Ruling questions: written, unanswered.

## Failure modes

- **Tightening on taste.** A refusal without a ground is an invented rule.
- **Over-refusal.** A tightening that turns a legal program red is a
  regression shipped as a fix. The legal sibling is not optional.
- **Refusing in the backend.** Catching it as a Zig error string, or pattern-
  matching emitted output, is not a Koru refusal. The diagnostic has a Koru code
  and points at the author's text.
- **A pin that was never red.** If you did not watch the compiler accept it at
  HEAD, you do not know your test tests anything.
- **Moving an existing pin** to make room. That is `010`'s banned move too.
- **Hunting where `010` hunts.** Tests already pinned red as `must-error-passed`
  are claimed. This frame finds the ones nobody wrote.
- **Narrating instead of compiling.** "This probably compiles" is unmeasured.
  Compile it.

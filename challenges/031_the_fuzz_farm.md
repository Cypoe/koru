---
challenge: the-fuzz-farm
kind: frame
status: standing
yields: one or more fuzz findings adjudicated to a fix + green pin, a red MUST_ERROR pin, or a recorded ruling
family: correctness
created: 2026-10-03
---

*Walker context — the recurrence that earned this frame. The compiler's recent
defect list is a list of accidents: a dangling `|>` swallowed in two of three
positions, a comment severing a chain, a tor line fusing into a field value.
`007` probes compositions by hand, `024` hunts accepted-but-must-not programs by
hand, `023` audits diagnostics by hand — every hunt was manual until a
collaborator's GA fuzzer landed as scratch and immediately exposed that `-c`
verdicts were false greens (`koruc --deep-check` exists because of it). The
mechanized stack is now tracked — `scripts/sibling_fuzz.py`,
`scripts/composition_gp.py`, `scripts/composition_census.py`,
`scripts/ga_prep.py` + `fuzz/ga.k` — and its first clean passes produced three
real defects in one night (fuse-and-emit → KORU164; comment-seam severance → the
stitcher fix; a branch-check bypass inside `| captured` → 510_125 red) plus a
diagnostic-honesty family (335_056). What was missing is the standing frame that
says how a finding becomes a deliverable instead of a parked lead.*

*The oracle doctrine lives in
`concepts/frag-a-coverage-hit-needs-an-emission-witness.md` — read it before
your first replay; it is the accumulated scar tissue, not optional background.*

---

## The brief (sealed — you are the contestant)

**Run one oracle leg fresh. Adjudicate every finding it produces.**

Pick a leg and run it against the current tree — never replay parked findings:

- `scripts/sibling_fuzz.py` — `|>` layout differential: same program, one trivia
  mutation, verdict flip means a defect. Three oracle tiers (verdict /
  `--print` diff / normalized AST emit diff).
- `scripts/composition_gp.py` — splices corpus-harvested subtrees into carriers,
  fitness = uncovered census cells. Run it under `--deep-check`.
- `scripts/ga_prep.py` + `fuzz/ga.k` — the self-hosting GA; seeds verified to
  compile at their pop location.

Then **adjudicate** — the protocol below turns each finding into a commit, a
red pin, or a ruled verdict. A finding you did not adjudicate is a lead:
report it under leads with its `.kfuzz/` repro path, don't leave it to rot.

---

## The oracle — the witness ladder

"It compiled" is not a verdict. A coverage claim survives only up the ladder,
and each rung is a place a green has already lied:

1. **Accepted** — `koruc` takes the program. Says nothing yet.
2. **Emitted** — the construct appears in `output_emitted.zig`. A splice inside
   a `Source`-block DSL can be accepted as opaque text and dropped unresolved
   (`std/runtime:register`'s line-scanner did exactly this).
3. **Emitted *valid*** — `zig ast-check` parses the emission. Fuse-and-emit
   pasted Koru source verbatim into Zig and `--deep-check` still reported
   green — it writes emission without checking it parses.
4. **Semantically present** — the construct's *steps* are in the output, not
   just a syntactically plausible skeleton. `510_125`: an unknown `if` arm
   inside `| captured` emitted as an *empty* `else` — valid Zig, body absent.
5. **Live** — the carrier is reachable from an executed root. Splices inside
   `proc|zig` bodies of tors `main` never calls are dead-stripped before
   emission; `gp_2`/`gp_11` scored PASS on constructs that never existed at
   runtime.

A green that fails any rung is adjudicated as *instrument noise* or a real
defect — never a coverage hit.

---

## Adjudication — every finding lands somewhere

- **Reproduce at HEAD first.** Verdicts drift with the tree; a parked "green"
  may now refuse (gp_9 did). Stale findings are noise — close them, don't
  re-file.
- **Real defect** → the fix in `src/`/`koru_std/` + a regression pin + a legal
  sibling control, per `024`'s grounding rules. A repro is not a fix; the
  commit is.
- **Must-be-legal-but-refused** or **accepted-but-must-not** → red pin:
  `MUST_ERROR`/`EXPECT` asserting the intended behavior, header prose naming
  the gap. Stays red until the work lands.
- **Design question** → do not guess the ruling: name the two honest options,
  the precedent each leans on, and park it in the finding note for the walk.
- **Instrument gap** → if the fuzzer or `koruc` can't distinguish "emitted"
  from "emitted valid," the oracle needs repair before the next replay —
  `--deep-check` still does not `zig ast-check` its own emission.
- A "can't be legal" claim cites the enforcer (file + refusal text) or a
  refusal-producing compile. Corpus absence is not a wall.

---

## Self-grounding

Before spending a replay: read the witness frag, the adjudicated pins
(`100_089`, `210_308`, `335_056`, `510_125`), and `.kfuzz/findings*` — know
which surfaces already produced signal and which produced noise. Re-adjudicate
parked findings only to re-measure staleness deliberately.

## Variance

Variance lives in **which leg, which corpus cells, which mutants** — the
differential leg and the census-GP hit different defect classes (layout seams
vs composition holes), and an uncovered-cell fitness target reaches where
random mutation doesn't. Variance never lives in hand-editing generated
programs: a probe you wrote is a `007` entry wearing a fuzzer's coat.

## Done-gates

- Each finding lands as commit(s): fix+pin, red pin, or recorded ruling —
  with the repro path preserved under `.kfuzz/findings*`.
- The pin's header describes the shape it guards, not today's red/green state.
- Foreign working-tree drift is not yours: stage your files by name, leave
  the rest.
- Leads you ran out of: repro path + classification, reported — not silently
  dropped.

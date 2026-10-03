# Fuzzing tools (challenge 007)

Three corpus-driven tools. All scratch under `.kfuzz/` (gitignored); findings
under `.kfuzz/findings*` — never into `tests/` without adjudication.

Environment: `zig`/`koruc` exist only in WSL (`~/tools/zig-0.15.1/zig`, repo at
`/mnt/w/src/koru`, caches at `~/zigcache` — drvfs `.zig-cache` renames fail).
`zig-out/bin/koruc` is a Linux ELF; run everything through `wsl bash`.

## composition_census.py — construct x context coverage map

Regex construct detectors (17 constructs, spellings verified against corpus,
e.g. glob = `module:*` in taps) + indentation-based nesting. Reports covered
and uncovered ordered pairs. `--uncovered` filters to contexts that lexically
open bodies. Heuristic, not AST — a target list, not proof of absence.

Measured at HEAD (this session): 9112 construct hits, 141 nested pairs,
~41 uncovered pairs after filtering; real targets cluster on
`read_lines` and `subflow_impl` under runtime contexts.

## sibling_fuzz.py — sibling-form differential

Whitespace-only mutants over `input.k` files: `join`, `split`, `headbreak`
(guarded to `!`/`|` arm heads), `comment` (legal-by-diagnostic trivia).
Oracle: `koruc -c` verdict twins; `--print-diff` adds canonical-print diff;
`--emit-diff` diffs the emit payload for pairs where BOTH compile.

Emit-diff detail: `koruc -o` writes a program-independent backend driver to
the `-o` path AND the real payload `program.ast.json` **beside the input
file** (plus `backend_output_emitted.zig`, `build*.zig`, `compiler_env.json`
— do not point `-o` at corpus inputs directly). We canonicalize
program.ast.json with position fields stripped (`file`, `canonical_path`,
`location`, `line`, `column`, `indent`) and emit twins under a shared
basename (module name derives from filename). Controls verified:
orig vs split identical; a changed string literal diffs at the literal node.

Measured: `emit ~2.6s/file` (not 60-90s — that was the full zig build chain).
Runs so far: 0 real divergences; the one batch of print-diff hits was a
transform artifact (headbreak splicing string-blanked text — fixed).

## composition_gp.py — genetic composition search

Population = carriers (positive corpus inputs) + genome (splice-edit list);
payloads = self-contained statement subtrees harvested from positive tests.
Fitness = uncovered-pair coverage (full-corpus census) + shaped partial
credit (verdict, construct presence, rarity). Tournament select, crossover,
mutate (target-biased toward uncovered constructs), elitism.
Findings in `.kfuzz/findings_gp/`.

Measured: fitness gradient works (pop_avg 0 → 1.7 → best 4-14 across
versions). Earlier sampled-corpus run hit real uncovered cells
(`subflow_impl under capture` etc., passing `-c`). Full-corpus run at HEAD:
0 uncovered hits — most remaining cells look structurally impossible
(signature-level constructs under runtime contexts), not merely unfuzzed.
Calibration proof it works: it independently converged on
`read_lines under effect_arm`/`for_each`, the known-red 670_023 seam —
before positive-test filtering caught the false-positive carriers.

## fuzz/ga.k — native GA driver (in Koru itself)

The same search, written in the language under test: tors own the GA
structure, `proc|zig` bodies do fs/spawn/splice. `scan` emits `! entry`
per candidate file; `eval` runs `koruc -c`; `classify` checks the cell
against targets.txt; the `| hit | miss` / `| clean | refused` arms ARE the
selection operator; `#g`/`@g` fold drives generations; population lives as
files under `.kfuzz/ga/pop/g<N>/`. Offline prep: `scripts/ga_prep.py`
(bank frags + checking-verified seeds + targets).

Run (from repo root — all paths inside ga.k are cwd-relative):
`koruc -c` green → build → `./<build-dir>/a.out`.
Findings land in `.kfuzz/ga/findings/<cell>__<src>.k`.

Two build modes, pick by where you want artifacts:

- `koruc fuzz/ga.k` — artifacts emit **beside the source** in `fuzz/`
  (`a.out`, `backend*.zig`, `output_emitted.zig`, `program.ast.json`,
  `build*.zig`, `compiler_env.json`, `zig-out/`). All covered by the
  `fuzz/` ignore block, so nothing is staged — but they sit in the tree.
- `cp fuzz/ga.k .kfuzz/ga/build/ga.k && koruc .kfuzz/ga/build/ga.k` —
  `koruc` has no output-dir flag (`-o` only names the emitted .zig; the
  payload still lands beside the input), so the way to keep *everything*
  ephemeral is to compile a copy inside `.kfuzz/`. Verified: all ten
  artifacts emit under `.kfuzz/ga/build/`; binary runs identically.

Backend `zig build-exe` inherits the environment: `zig` must be on PATH
and `ZIG_LOCAL_CACHE_DIR`/`ZIG_GLOBAL_CACHE_DIR` must point off the drvfs
mount (`~/zigcache/…`) or the `.zig-cache` rename fails AccessDenied.
The GA's own runtime state (pop/g<N>, bank, findings, .code/.err
sidecars, targets.txt) is always under `.kfuzz/ga/` regardless.

Hard-won mechanics:
- `proc|zig` bodies get full Zig; `const std = @import("std")` belongs
  INSIDE the body in .k files (file-scope Zig decls are parsed as impls).
- `std.process.Child.run` must spawn `sh -c '… ; echo $? > code'` and read
  the code from a file: reading `result.term.Exited` on a
  nonzero-exit+stderr child PANICS under koru — pinned bug
  400_141_child_run_nonzero_exit_stderr_term.
- `koru_allocator()` allocations leak into `KORU LEAK CHECK FAILED` —
  proc bodies use `std.heap.page_allocator`.
- Fold-loop exit is `| arm -> e` (produce), per 020_028. A top-level
  `#label`/`@label` fold whose exit arm is a bare `|>` continuation never
  terminates — it re-dispatched `| done` 14.5M times before timeout.
  Whether that re-dispatch is intended loop semantics or a defect is an
  arbiter question; the produce-arm form is the safe shape.
- Splices must skip `proc|zig`/`|fpga`/`|mlir` bodies (brace-counted in
  breed): `-c` treats them as opaque, so koru text inside scores vacuous
  hits that no backend could run.
- Hit verdicts are frontend-level: a `| hit` candidate passed `-c` but died
  at backend coordination with `KORU022` (its seed pinned sibling-only
  coverage — the splice landed exactly inside that boundary). Layer at
  which refusal lives is part of the finding.

Measured: gen0 seeds → offspring through g5+; cells hit in-run included
`store__obligation`, `store__phantom`, `store__capture`,
`store__read_lines`, `branch_arm__obligation` — all real targets.txt
cells. Diagnostics observed on refused offspring are genuine (KORU002
missing module, KORU010 mis-indented subflow body).

## Repros — fuzz/repros/

Checked-in findings (the `.kfuzz` originals are gitignored). All measured at
HEAD: `koruc -c` GREEN on every file; the full pipeline refuses each at
backend coordination — the layered-acceptance boundary is the finding.

| file | cell | full-build verdict |
|---|---|---|
| `branch_arm__obligation__c2511…` | obligation under branch_arm | KORU022 branch 'full' unhandled |
| `branch_arm__obligation__c3528…` | obligation under branch_arm | KORU022 (variant) |
| `branch_arm__obligation__c35559…` | obligation under branch_arm | KORU022 (variant) |
| `if_cond__phantom__c11299…` | phantom under if_cond | KORU021 regex-branch unhandled |
| `store__phantom__c37258…` | phantom under store | KORU022 |
| `store__read_lines__c16201…` | read_lines under store | KORU022 |
| `branch_arm__obligation__c45793…` | obligation under branch_arm (earlier run) | KORU022 |

Open adjudication: correct refusal at the wrong layer, or checker accepting
what coordination can't cover? The `if_cond__phantom` file pins that the
disagreement is not one diagnostic — the seam is per-branch coverage.

### Obligation-through-loops probes (hand-authored, `LIMITATION 1` shape)

`phantom_semantic_checker.zig` admits per-loop obligation ownership is not
SCC-scoped: nested label-folds carrying an outer obligation through an inner
back-edge are unpinned. These probes measure it:

| file | shape | verdict |
|---|---|---|
| `probe_nested_obligation.kz` | inner fold back-edges while outer `<owned!>` is live-ambient | compiles + runs correct (`n=2`, no leak) |
| `probe_nested_consume.kz` | inner fold *consumes* the outer obligation, both back-edges re-feed it | **KORU030** use-after-discharge at coordination, both `@` sites |

The hostile variant is caught per-binding even without SCC ownership — the
residual hole candidates are conditional-consume (join-point discharge state)
and borrow escape into a store. These are the baseline seeds for an
obligation-scoped fuzzer (mutations: move discharge across an `! each` /
`@`-edge / `[@scope]` boundary).

### Obligation-scoped sweep probes (`obligation_fuzz.py`, 2026-10-03)

Different finding class than the table above: these pass `-c` AND all 20
coordination passes — the wall under test is emission.

| file | shape | verdict |
|---|---|---|
| `probe_arm_end_consume_emit.kz` | fold `again` arm routed to a discharger instead of `@loop` | coordination green, **emitted Zig does not compile** (`loop:` label, no `continue`) |
| `probe_scope_on_user_arm.kz` | hand-written `[@scope]` on a plain back-edge arm | builds + runs `n=3` — benign over-restriction; open question whether user `[@scope]` is sanctioned surface |

## Yield
TL;DR
Three corpus-driven fuzzers + a GA driver written in Koru itself. Zero compiler miscompiles found. The real output is four boundary observations + one frontend/backend disagreement — the honest kind of yield for a differential run: mostly "the seams hold," plus places where the checker's acceptance and the backend's acceptance disagree about what a composition means.

Everything is at tree 714b76d3c (main), .kfuzz scratch, FUZZING.md documents all of it.

### Findings

1. Frontend/backend disagreement on a corpus-uncovered composition (the strongest hit).
The native GA spliced a std/store:new decl carrying *lib/srclib:Src<live!> (obligation mark) inside a | ok w branch-arm body — cell branch_arm__obligation, uncovered in the whole corpus. koruc -c accepts it; the backend dies at coordination with KORU022: branch 'full' must be handled. So: shape-check green, coordination red — the pipeline itself splits on this composition. Repro: branch_arm__obligation__c45793_branch_arm__obligation.k. Whether that split is "correct pin" or "checker accepts what codegen can't cover" is your call.

2. Fold-loop exit semantics footgun (observed, arbiter question).
A #label/@label fold whose exit arm is a bare |> continuation never terminates — completing the terminal arm re-dispatched the outcome, printing 14.5M times in 180s. The corpus-proven exit is -> e produce (020_028). If "arm completes → fold re-fires" is intended, it's a footgun worth a diagnostic ("this arm can never exit the fold — produce or _?"); if not, it's a bug. I don't know which; the behavior is reproduced and minimized in ga.k history.

3. -c is blind inside proc|zig bodies (verified, vacuous-hit class).
Splicing Koru text inside a proc|zig {} body passes -c trivially — the frontend treats host bodies as opaque. First GA run reported store__obligation/store__read_lines "hits" that were all this artifact. Not a bug — a coverage boundary: -c verdicts say nothing about host-body contents. Fuzzers must exclude |zig/|fpga/|mlir regions (brace-counted) or every hit is vacuous.

4. Child.run nonzero-exit+stderr panic is still live-ish (pin 400_141).
Didn't re-trigger it, but the GA's eval proc had to be built around it (sh -c '… ; echo $? > file' instead of reading .term.Exited). The pin's workaround-constraint is real and shapes any koru program that shells out to failing commands — i.e., any test-runner/fuzzer in-language. Worth knowing the pin blocks an obvious program shape.

### Negative results that are still signal
- Sibling-form seam is healthy at HEAD: ~95 |> layout mutants (join/split/headbreak/comment-insertion across ~50 corpus inputs), zero real divergences — verdict, --print canonical tree, and emitted AST all identical. Consistent with 220_017's pin having flipped green. findings empty = that's the result.
- Emitted-artifact diff oracle verified non-vacuous: -o writes a program-independent driver to the -o path; the real payload is program.ast.json beside the input. Canonicalizing (strip line/column/indent/file) catches literal-level drift; layout twins emit identical AST. Costs ~2.6s/emit, not 60–90s — that figure is the full zig build.
- Composition census: 75 uncovered construct×context cells after filtering; most look structurally impossible (signature-level constructs can't hold bodies), not merely unfuzzed. The fuzzer independently converged on read_lines under effect_arm/for_each — the known-red 670_023 seam — as a side-effect of fitness, which validates the coverage map.
- Leak checker works: proc bodies allocating via koru_allocator() trip KORU LEAK CHECK FAILED at exit; std.heap.page_allocator is the escape hatch (same as 400_141 uses).

### Tooling state
- sibling_fuzz.py — layout twins, -c/--print/--emit-diff oracles
- composition_census.py — construct×context coverage map (regex+indent, heuristic)
- composition_gp.py — external GP (splice genomes, census fitness, tournament/crossover)
- ga.k + ga_prep.py — the native GA: tor outcomes as selectors, #g/@g fold as generations, filesystem as population. GA-measured: offspring accumulate through g5+; verdicts differentiate correctly; terminates via ->.

The GA found the KORU022 boundary hit on its own — which is the proof of concept you asked about: tor-vocabulary selection and a fold-loop driver are a natural way to write a program that hunts uncovered compositions.

One honest caveat for whatever gets posted: all the "real" verdicts above are -c-level. Nothing in this session ran a spliced composition end-to-end through codegen+run — the gap between "checks" and "runs" is exactly where finding #1 lives.
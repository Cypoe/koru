# verify-path — review handoff (2026-10-11)

Branch off `ccomp`'s tip, 7 commits of session work on top. This note
is the map; the detail lives in the appended `verify-path session`
sections of `koru-callsite-proofs-draft.md` and
`koru-c-lane-test-plan.md` — your questions are verbatim, our answers
sit next to them marked Ruled / Still open / Parked. Second pair of
eyes wanted on the *deltas*, not the plan itself — K1–K4 and N1 stand.

## Demonstrated, not asserted

- `ccomp -O -c part.c` → `zig build-exe main.zig part.o -lc` links and
  runs; zig calls into CompCert-compiled code, rc 0 (CompCert 3.18,
  zig 0.16.0, aarch64-linux container).
- `std/witness` scaffold is live: `~std/witness:enforce { }` runs at
  comptime and returns `.enforced` through the declaration's own arm;
  `koruc prog.k witness` prints an obligation + routing census. ~150
  lines of `.kz`, zero compiler changes — the surface rides
  `command.declare` + `[comptime]` transforms + `ast_find` folds.

## Deltas from the ccomp plan (and why)

- **No `--lang=c` product toggle** — `c` is a verification arm that
  never ships; `enforce` in source owns the arm-switch. (`--lang=c`
  is fine as internal plumbing; the ruling only bars it as a shipping
  column.)
- **`enforce` = "verify this program"** — a `[comptime]` declaration
  in the `std/build:variants` family (310_051). Verification becomes
  a property of the program, not of the invocation. Arm-shape
  agnostic: it means the same thing whether the arm is whole-program
  or per-unit.
- **Module-owned commands** — `std/witness` ships `[comptime|command]`
  tors (the `explain`/`gate` mechanism) as its driver surface, plus an
  `[explainer]` tor participating in the shared catalog. Explain
  participates; it does not drive.
- **The refusal table is the coverage instrument** — under
  whole-program lanes, out-of-fragment programs refuse naming *every*
  axis (C2 recommendation); the diagnostics measure what the wall
  costs rather than hiding it.

## Parked, not repudiated

- **Per-unit partition + `|c[verified]`** — coverage granularity at
  the price of new language surface for toolchain QA. Whole-program
  is the degenerate case and the lowering carries over; it returns
  only if measured refusal rates prove the wall costs too much.

## Correction to the record

- `!` is a *leading* arm marker (`! discharge item |> …`, 690_097),
  not a `| !` branch label — and its families split differently for
  lowering: store interceptors/watches transplant into write paths at
  comptime (690_016) → sequential → eligible; only resumable pairs
  (coroutines) cannot lower. C1 dissolved into that eligibility split.

## Rulings made / still open

- **Made (Lars):** W1 (.marks + `std/witness` vocabulary home), W7
  (absorb — the injected pass IS the checker), C5 (`.kc` = `.kcs`
  verbatim), `enforce` shape, flat enforcement level, the
  commands-vs-explain split.
- **Open:** W2-rendering (deferred to implementation), W3, W4 (the
  `witness` command makes it empirical per-program), C2, C3, C4
  (leak exemplar — needs invention), `enforce` body/branches spelling.
  All recorded inline under "Still open" in each doc.

## Where eyes would help most

- **`enforce`-in-source vs a harness flag** — the biggest divergence
  from K1's original shape; tell us if it reads wrong to you.
- **The three-arm picture** — ccomp oracle / zig product /
  clang-sanitizer arm on the same `output_emitted.c`; sanity-check
  the shared-LLVM correlation claim (`zig cc` is clang — same
  middle-end family as the zig lane, so never the oracle).
- **Absorb over wrap** — `phantom_semantic_checker` demotes to
  obligation-set producer and the new pass owns the verdict. If that
  is wrong for reasons we have not seen, now is the cheap moment.


---

# pass-graph rungs 1-3 landed (2026-10-14) — and a spelling for you

Three more commits on `ccomp` since this handoff was written:
`b2673bf54` (requires on tors, KORU180), `430c9cd8d` (transform
requires/preserves, KORU181 blast radius), `e94bfeeb9` (committed arc
corpus the Lean oracle re-decides). `96707aabd` registered the new
vocabulary in the concordance matrix. The declared order is still
authoritative everywhere — the graph validates, never reorders; the
witness arcs commit what the validator checked; the oracle re-decides
the same rules on the lines alone.

## The collision: `[requires]` vs `std/compiler:requires`

Two surfaces now own the same word:

- **`std/compiler:requires`** — the pre-existing *directive tor*. The
  frontend reads its body as backend build requirements (the build-dep
  spelling). This was already in the tree.
- **`[requires("a","b")]`** — the pass-graph *call-annotation* on tors
  and transform decls, landed in rungs 1-2. Declares an ordering edge:
  "this pass's requirements must run strictly earlier in every chain
  that runs it" (pipeline) or "must sit in a strictly earlier stage"
  (transforms). Same grammar slot as `depends_on`/`preserves`, not the
  same slot as the directive tor.

They never parse into the same position — a tor name vs an annotation
argument — so the compiler is never confused. The collision is semantic,
and it's real: `~[requires("x")]tor a` reads naturally as "tor a needs
x to build", which is the *directive's* meaning, not the ordering edge's.

**Executive decision taken to unblock: keep `[requires]`** — the English
word is the right one for a prerequisite, the grammar slots are disjoint,
and `std/compiler:requires` is a niche directive surface most users never
spell. Recorded here for your final call; the rename is mechanical if you
want it (annotation-parser lookup + compiler.kz/taps.kz seeds + tests +
corpus lines).

Options:

- **Keep `requires`** — as shipped. Cost: the misreading above lives in
  the vocabulary; docs carry the disambiguation.
- **`after("x")` / `runs_after("x")`** — names the ordering semantics
  directly, kills the collision. Cost: slightly weaker noun for
  "prerequisite", reads backwards to dependency-graph convention.
- **`requires_order("x")`** — keeps the word, disambiguates the
  semantics. Cost: uglier, and the collision is only softened.
- **Fold ordering into `std/compiler:requires`** — one word, one owner.
  Cost: mixes build-dependency and pipeline-order semantics in one
  directive — the two namespaces don't overlap (build deps name files/
  steps, pass edges name tors), so a reader couldn't tell which a given
  entry is without checking resolution. Rejected on those grounds.

`preserves` has no collision. Lars's call on the rest — the rung-2
commit message carries the same note.

**Resolved 2026-10-17 (Lars): `contract:` namespace.** None of the
options above — the family spells `contract:requires`,
`contract:preserves`, `contract:obliges`. The namespace does the
disambiguating work a rename alone couldn't: it also clears the deeper
`depends_on` collision Lars surfaced (build steps and store rules use
`depends_on` for topo-sort-me edges; the pass graph validates authored
order and refuses — opposite contract, so sharing the word would have
misled worse than `requires` did). The namespaced spelling reads as a
member of the existing claim-stamp idiom (`[measured]`/`[proven]`/
`[aspirational]` vertical blocks) — annotations are namespaced names
already (`[registry:scope(...)]`), so no grammar work was needed.
Vertical-block form for the compiler.kz seeds and `tap`, one contract
claim per dash; witness wire tokens (`pass-graph-edge … requires …`,
`preserves=`, `obliges=`) deliberately unchanged — the attested corpora
and `WitnessCheck.lean` stay byte-valid.

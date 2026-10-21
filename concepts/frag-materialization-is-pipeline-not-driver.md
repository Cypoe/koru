---
type: belief
id: frag-materialization-is-pipeline-not-driver
provenance: emission-pipeline session 2026-10-21 — `--lang` was ambient
  authority read at ~18 sites and the generated backend driver owned a
  fixed ~250-line post-coordinate tail; both moved into routed pipeline
  tors (compiler.kz emit-*-artifact chains), driver slimmed to
  `RuntimeEmitter.emit` + discard
ts: 2026-10-21
tags: [koru, coordinate, emission, driver, target-selection]
---

# Artifact materialization is pipeline composition, not driver privilege (belief)

A compile used to end where `coordinate` returned `{ast, code, metrics}`:
the generated backend driver then ran a fixed tail — pick the
`output_emitted.<ext>` filename, write it, run the `--deep-check` zig.Ast
witness, pick the Stage-D verb (`zig build` / `dotnet build` / nothing),
copy the binary to `-o`. None of that was a step; no user override could
change the filename, emit two artifacts, or implement emit-only without
patching the generator. And `--lang` was consulted *three times* in three
layers — inside `emit-zig`'s proc body, in the driver's filename select,
and in the driver's Stage-D dispatch — so a `glance` of the pipeline could
not say which emitter ran.

Now the tail is tors: `target-of` routes the flow on the target union
(`zig|js|cs|other`), and per-target impls spell the chain —
`emit-zig-artifact = emit-zig |> write-artifact |>
branch(deep-check) | yes |> validate-emitted | no |> host-build-zig`.
Every stage is named, `|>`-composable, and user-callable: dropping
`host-build-zig` is an emit-only pipeline, interposing a step between
write and build is a source-level rewrite hook. The driver's post-
coordinate body is one line — `_ = try RuntimeEmitter.emit(...)`.

And the steps take params, so the controls are pipeline arguments, not
ambient state: `emit-*-artifact` carries `output: ?string` (the produced
binary — overrides the `-o` argv read) and `dir: ?string` (relocates the
emitted artifact under a directory). `write-artifact` makes the dir and
joins; `host-build-*` reads the artifact back from it. The one
combination that cannot work refuses as KORU209 — `dir:` +
`build:requires`, because `build_output.zig` is emitted at Stage A and
reads `output_emitted.zig` from cwd. The line-growth wall enforced the
first split inside the part: host toolchain verbs now live in
`compiler.materialize-build.kz` (`~part materialize-build`) — artifact
steps vs Stage-D drivers is the seam it chose.

`other` is not a fallback: KORU126 refuses undeclared `--lang` names
upstream, so the only tags that reach `| other` are declared proc-variant
tags (|mlir, |gpu) — the tag selects which proc bodies emit and the host
artifact legitimately stays Zig. `cs` is a third *emitter* in the
KORU126 allow-list (it used to pass only via the back door — std
declares `|cs` bodies in every merged program).

The contract change is real and deliberate: a `coordinate` override that
never routes through `emission` now produces *no artifact* — the code
string alone is not materialized. Materialization is something the
pipeline does, not something done to whatever the pipeline returns.

Two honest boundaries remain, and they bound rather than leak:

- **`build_output.zig` stays frontend.** It is emitted at Stage A from
  `build:requires`, before the backend exists — same category as
  `build_backend.zig`, not a backend materialization gap.
- **`--deep-check` reaches the flow as data** via `std/compiler:has-flag`
  + `std/compiler:branch` — the flag is still ambient underneath
  (`compiler_env.json`), but the *decision* is a visible arm in the
  chain, not an if inside fixed Zig. Same for `emit-*-artifact`'s
  `--release=`/`-O`/`build:config target` reads inside `host-build-zig`.

Pin: `430_016_emission_override_routed` overrides `emission` alone, spells
the zig arm's five steps raw (including a nested `branch` inside the
arm), and runs cross-target through zig and cs.
`430_017_emission_artifact_params` pins the `dir:`/`output:` params
end-to-end — the artifact stages under `stage/` and the build reads it
back from there (post.sh asserts the relocation both directions). What remains ambient is
the ~15 `[comptime|transform]` sites reading `CompilerEnv.lang` — their
`{expr, reporter}` signature takes no ctx, so threading target as data
through them is a transform-contract change, not this one.

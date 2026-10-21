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
(`zig|js|cs|other`, fallback to zig), and per-target impls spell the
chain — `emit-zig-artifact = emit-zig |> write-artifact |>
branch(deep-check) | yes |> validate-emitted | no |> host-build-zig`.
Every stage is named, `|>`-composable, and user-callable: dropping
`host-build-zig` is an emit-only pipeline, interposing a step between
write and build is a source-level rewrite hook. The driver's post-
coordinate body is one line — `_ = try RuntimeEmitter.emit(...)`.

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
arm), and runs cross-target through zig and cs. What remains ambient is
the ~15 `[comptime|transform]` sites reading `CompilerEnv.lang` — their
`{expr, reporter}` signature takes no ctx, so threading target as data
through them is a transform-contract change, not this one.

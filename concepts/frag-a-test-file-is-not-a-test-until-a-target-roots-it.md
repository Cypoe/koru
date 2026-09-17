---
type: belief
id: frag-a-test-file-is-not-a-test-until-a-target-roots-it
provenance: 2026-09-17, koru. Found while fixing a sibling defect — an assertion added to flow_checker.zig passed with a false expectation written into it, which is not something a running test does.
ts: 2026-09-17
---

# A test file is not a test until a target roots it (belief)

`src/*.zig` carries inline `test` declarations, and `zig build test` runs a
FIXED LIST of test targets. A file that no target roots — and that no root pulls
in through `refAllDecls` — is compiled, shipped, and never executed. Its tests
cannot fail, so they cannot inform, and they look exactly like tests that can. A
`*_test.zig` filename is not evidence of anything: naming a file after the thing
it tests wires nothing.

Measured 2026-09-17 by appending `test "__omp_liveness_probe" { expect(false); }`
to every file under `src/` that declares a top-level test, then running the real
`zig build test`: **24 files, 182 test declarations, never ran.** The set
includes suites that were plainly written as suites — `glob_matcher_spec_test.zig`
(37 declarations), `emitter_test.zig` (25), `branch_checker.zig` (24),
`comptime_eval_test.zig` (21) — and three files (`glob_matcher_spec_test.zig`,
`parser_call_suffix_test.zig`, `frontend_completion_test.zig`) are named nowhere
in `build.zig` at all. Others have an opt-in step (`zig build test-comptime-eval`,
`test-phantom-checker`, …) that nothing `dependOn`s: the default `test` step does
not include them, and `run_regression.sh` invokes only `zig build test`.

## The method, which is the durable part

Do not audit this by reading `build.zig` and reasoning about reachability — that
is the predicate-less reading that produced the wrong numbers on the negative-test
corpus. Inject an assertion that MUST fail into every candidate file and run the
enforcer's own command once: whatever still exits 0 is not running. One command,
no per-file bookkeeping, and no opinion required about how targets compose.

The tell worth remembering: **a test that passes when you make it expect `false`.**

## What this is not

Not a claim that each of those 182 is well-written, and not a claim that all of
them should be wired — some may be superseded. It is a claim about where they
stand: outside the wall, unmeasured. Wiring is a `build.zig` change, so the
disposition is a maintainer's. See
[[frag-a-register-of-guards-must-be-derived-not-written]]: a suite's membership
should be derived from the target graph rather than from a list someone maintains
by hand — and this is what the hand-maintained list cost.

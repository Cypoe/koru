---
challenge: unarmed-reject-pins
kind: frame
status: standing
yields: every reject-style test dir carrying expected_error.txt with no MUST_ERROR/EXPECT marker either gets its markers or is explained — the pin file is currently never opened by the harness
family: toolchain
---

# Unarmed reject pins — expected_error.txt files the harness never reads

Measured 2026-10-28 on `Cypoe/challenge-005-regression-board-triage`
(tree 9f8576850 + a0141de2d): 7 test dirs under
`tests/regression/300_ADVANCED_FEATURES/390_KERNEL/` carry
`expected_error.txt` but **no `MUST_ERROR` and no `EXPECT` marker**:

- 390_023_require_computed_in_pipeline
- 390_050_reject_for_in_kernel
- 390_051_reject_branch_constructor_in_kernel
- 390_054_require_computed_branch
- 390_104_reject_f64_gpu_kernel
- 390_122_reject_self_fpga_under_step
- 390_123_reject_self_fpga_param

`scripts/regression_lib.sh` only checks `expected_error.txt` inside the
`MUST_ERROR` / stage-expectation branches — with neither marker the file
is dead text (the same pathology the `expected_output.txt` wall at
regression_lib.sh:808 was built for, one filename over). If the input
errors the test reads as an *unexpected* failure; if it ever compiles
clean the test greens while the pin asserts nothing.

Verified: `390_104`'s input refuses with `error[KORU123]: ... requires
an f32 shape` — the pinned text — yet the dir reds as an unexpected
error. Prior art for the correct shape: `390_117` and `390_133` carry
`MUST_ERROR` + `expected_error.txt`; `390_127`/`390_128` carry
`MUST_ERROR` + `EXPECT` with `BACKEND_EXEC_ERROR` + CONTAINS pins.

Yield per replay: arm one cluster — add `MUST_ERROR` + `EXPECT` naming
the stage the refusal actually fires at (measure it; `390_104` fires at
backend exec), keeping the existing pin strings, OR file which reject no
longer fires. Two-line sweep: also worth a `regression_lib.sh` config
wall — `expected_error.txt` without `MUST_ERROR` should be a
config-error like `expected_output.txt` already is.

---
challenge: tap-when-guard-composition
kind: pin
status: standing
yields: one measurement + ruling on handler-guard x tap-guard composition under taps/profiler
family: toolchain
---

# Tap x when-guard composition

`wrapContinuation` in `koru_std/taps.kz` installs the TAP's `when` clause on the
wrapped handler continuation and drops the HANDLER's own `condition` —
deliberate in the code ("Use the TAP's when clause condition"), never ruled on.
So `| branch x when COND |> ...` under a universal or matching tap becomes
unguarded when the tap carries no `when`, or guard-swapped when it does.

Unmeasured (2026-10-29): whether any test or real program composes a guarded
handler with a tap today — and if so, whether the correct composition is
handler-guard AND tap-guard, handler-guard alone, or a refusal. Found while
fixing the kind-drop in the same function (commit 4086c2977 on
Cypoe/challenge-020-profiler-toolchain-join); the fix preserved the
pre-existing condition choice deliberately.

Yield: a minimal repro under `360_TAPS_OBSERVERS/` (e.g.
`516_tap_when_guard_composition`) — `for ! each i when i > 0` or a
`| branch x when` arm under `* -> *` profiler or a plain `std/taps` tap —
measuring which guard actually decides firing, then either the semantic fix
(conjunct the guards) or a MUST_ERROR ruling if the composition is refused.

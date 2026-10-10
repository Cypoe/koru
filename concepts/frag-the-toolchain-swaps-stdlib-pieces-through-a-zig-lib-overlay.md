---
type: belief
id: frag-the-toolchain-swaps-stdlib-pieces-through-a-zig-lib-overlay
provenance: commissioned serializer audit — std.json.Stringify measured ~40% of /json CPU on the orisha HttpArena entry
ts: 2026-10-11
---

# The toolchain swaps stdlib pieces through a zig-lib overlay

## Belief

Koru may ship byte-identical, faster replacements for files in zig's own
`lib/std/` and deliver them to every emitted program without touching the
user's source or the installed zig toolchain. The mechanism is emitted, not
ambient: `generateBackendCode` writes `__koruEnsureZigLibOverlay` into every
backend — it runs `zig env`, builds `.zig-cache/koru_lib_overlay` as a symlink
mirror of the real lib dir with the patched file swapped in (std/ and
std/json/ mirrored one level deep so a single file can be replaced), keys
reuse on a `.koru_src` marker, and appends `--zig-lib-dir` to the
`zig build`/`zig build-exe` invocation.

## Why

`std.json.Stringify` measured ~40% of /json CPU on the orisha entry and
~17.6% inside `encodeJsonString` alone. The upstream file is byte-at-a-time;
the patch (comptime-escaped field names, fused punctuation, SIMD escape
scan, batched `writeAll`) is 2.05× on the serialize leg and +41% on the
endpoint, with output byte-identical across the option matrix (442 checks).
Because the swap is byte-identical, every failure mode is allowed to be a
silent degrade: wrong zig version, missing patch, failed symlink — warn and
build against stock std. Correctness never depends on the overlay existing.

## Constraints

- The gate is a hard version check (`zig env` `.version` == the zig the
  patch was verified against). On any other version the overlay refuses —
  a stale patch is worse than none.
- The patch must stay byte-identical to stock behavior; it is an
  optimization, not a dialect. Its test is the option-matrix byte
  comparison, not the benchmark.
- Reuse is keyed on the real `lib_dir`, so a zig upgrade invalidates the
  overlay without stale-state risk.
- `--zig-lib-dir` applies to the emitted program's own build — this is not
  a change to how koruc itself is built, and not a change visible in `.k`
  source. The disclosure lives in the emitted backend source and the
  fallback warning.

## Open questions

- Whether overlay construction (one `zig env` spawn + ~N symlinks on first
  build) is worth caching more aggressively than the `.koru_src` marker.
- Whether other std files want the same treatment — the mechanism is
  generic; `Stringify.zig` is just the first payload.
- Concurrent first-builds in one project dir could race on overlay creation
  (tmp+rename mitigates, unproven under load).

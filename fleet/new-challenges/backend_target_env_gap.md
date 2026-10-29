---
challenge: backend-target-env-gap-on-old-bases
kind: pin
status: standing
yields: a fleet-environment pin — KORU_BACKEND_TARGET is documented but unread on pre-existing worktree bases; backend can't exec on glibc-2.31 hosts without a manual -Dtarget rebuild
---

# KORU_BACKEND_TARGET is prescribed by env docs but unread on older worktree bases

Measured 2026-10-29 on worktree `022-the-std-surface-census` (HEAD
9f8576850): the fleet env doc and main's `AGENTS.md` prescribe
`KORU_BACKEND_TARGET=x86_64-linux-gnu.2.31` for Ubuntu-20.04/glibc-2.31
hosts, but `grep -rn KORU_BACKEND_TARGET src/ koru_std/ scripts/` in that
tree returns **zero hits** — `emit_build_zig` predates the mechanism
(main's `AGENTS.md` documents it as "Emitted build.zig files honor it as
the default target", so the fix exists upstream and the worktree base is
simply older). Symptom: `koruc` runs the four-stage pipeline, `zig build`
produces a backend whose native-target resolution emits
`__libc_start_main@GLIBC_2.34`, and `./zig-out/bin/backend` fails
`version 'GLIBC_2.34' not found`. Workaround measured this session:
`zig build --build-file <out>/build_backend.zig -Dtarget=x86_64-linux-gnu.2.31`
in the output dir, then overwrite the newest entry in
`~/.cache/koru-backend-cache/` with the resulting binary — the next koruc
run prints `✓ Backend cache hit` and completes. Yield: this pin (the
workaround), or a backport of the `KORU_BACKEND_TARGET`/`emit_build_zig`
hook to fleet bases if rounds keep landing on pre-mechanism trees.

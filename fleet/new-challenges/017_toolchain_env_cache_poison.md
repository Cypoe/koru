---
challenge: toolchain-env-cache-poison
kind: instrument
status: standing
yields: koruc/zig caches can never serve a binary the current toolchain cannot run
family: toolchain
---

## What was measured (2026-10-28, worktree 016-the-honest-board)

Every `backend-exec` failure on a WSL board traced to one cause: zig's native
libc detection probes `cc` from PATH, and `~/.nix-profile/bin/cc` resolves to
**nix glibc 2.44** (`zig libc` reports `/nix/store/...-glibc-2.44-25`). The
system libc is 2.31, so every natively-built backend binary requires
`__libc_start_main@GLIBC_2.34` and cannot exec — `backend-exec` on every test.

The poison then propagates through TWO content-keyed caches that carry no
toolchain key:

1. **zig's own artifact cache** (`ZIG_LOCAL_CACHE_DIR`, fleet-shared at
   `/tmp/koru-backend-cache`): 2.34-requiring `o/*/backend` binaries written
   2026-10-28 14:13 and 16:51 were served into later builds at 17:44 on cache
   hit — zig never re-linked.
2. **koruc's `koru-backend-cache`** (`src/main.zig` `backendCacheKey`): the key
   covers `src/` + `koru_std/` + emitted files. Nothing in the key sees the
   resolved target, the libc, or the compiler toolchain — so a binary linked
   against nix-glibc is stored and re-served to hosts that cannot run it.
   `frag-a-backend-cache-keyed-on-mtime-can-serve-poison` records three
   key-coverage failures already; this is the fourth axis — the key is
   complete over *source* and blind over *environment*.

## The gap

`KORU_BACKEND_TARGET` is prescribed in fleet docs for exactly this (pin
`x86_64-linux-gnu.2.31`), but **nothing in this tree reads it** — grep finds
zero matches. Either wire it (koruc passes `-Dtarget=` / a `--libc` file into
the backend `zig build`, and/or hashes the resolved toolchain into
`backendCacheKey`), or make the suite refuse to run under a misdetected
toolchain (a preflight that builds+execs a trivial `-lc` binary would have
named this in seconds instead of 2000 red tests).

Minimum honest slice: add the resolved-target/toolchain hash to
`backendCacheKey` so caches stop serving foreign binaries, plus a suite
preflight that fails loud when the backend can't exec.

## Workaround verified

Strip `~/.nix-profile/bin` from the front of PATH (append it last so `node`
still resolves): `cc` then finds system glibc 2.31 and backends exec. Private
cache dirs (`TMPDIR=/tmp/<private>`) avoid re-serving existing poison.

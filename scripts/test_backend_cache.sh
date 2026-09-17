#!/bin/bash
# Backend-cache invariants: the salt is content, and the cache is bounded.
#
# Guards the two properties the 81c8fa8b6 fix established, both of which fail
# silently if reverted — a mtime salt mints a dead generation per rebuild and
# leaks disk, and an unbounded cache only shows up as a full volume:
#
#   1. the salt moves on content, not on mtime or a rebuilt koruc binary;
#   2. entries are evicted LRU to a byte cap, never inside a live window.
#
# Runs against a scratch cache dir and a synthetic test dir. It invokes no
# `zig build` and no regression test, so it is safe and cheap (~5s) to run at
# any time, including while a board holds the suite lock.
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO/scripts/regression_lib.sh"
source "$REPO/scripts/regression_cache.sh"

pass=0; fail=0
ok()  { echo -e "  ${GREEN}ok${NC}   $1"; pass=$((pass + 1)); }
bad() { echo -e "  ${RED}FAIL${NC} $1"; fail=$((fail + 1)); }
eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1 (expected [$2], got [$3])"; }
neq() { [ "$2" != "$3" ] && ok "$1" || bad "$1 (unchanged: [$2])"; }
mt()  { stat -c %Y "$1" 2>/dev/null; }

S=$(mktemp -d "${TMPDIR:-/tmp}/koru-cache-test.XXXXXX")
trap 'rm -rf "$S"' EXIT

# ── salt: content, not mtime ────────────────────────────────────────────────
echo "salt fingerprint:"
CR="$S/compiler"; mkdir -p "$CR/src" "$CR/koru_std"
printf 'const a = 1;\n'   > "$CR/src/a.zig"
printf 'pub fn flow() {}\n' > "$CR/koru_std/c.kz"
printf 'build\n'         > "$CR/build.zig"

F0=$(cache_compute_compiler_fingerprint "$CR")
eq "is a 64-hex digest" "64" "${#F0}"
eq "is deterministic" "$F0" "$(cache_compute_compiler_fingerprint "$CR")"

sleep 1                                    # the mtime it must ignore is in whole seconds
touch "$CR/src/a.zig" "$CR/koru_std/c.kz"
eq "unchanged by touch (mtime is not a build input)" "$F0" "$(cache_compute_compiler_fingerprint "$CR")"

head -c 4096 /dev/zero > "$CR/zig-out.test"   # a rebuilt binary is not an input either
printf 'const a = 2;\n' > "$CR/src/a.zig"
neq "moves on content" "$F0" "$(cache_compute_compiler_fingerprint "$CR")"
F1=$(cache_compute_compiler_fingerprint "$CR")

printf 'const a = 2;\n' > "$CR/src/renamed.zig"; rm -f "$CR/src/a.zig"
neq "moves on rename with identical bytes (names are hashed)" "$F1" "$(cache_compute_compiler_fingerprint "$CR")"

rm -f "$CR/src/renamed.zig"; printf 'const a = 2;\n' > "$CR/src/a.zig"
eq "returns to the prior value when the tree is restored" "$F1" "$(cache_compute_compiler_fingerprint "$CR")"

# ── key: salt + inputs, and nothing else ────────────────────────────────────
echo "cache key:"
export BACKEND_CACHE_MODE=on
export BACKEND_CACHE_DIR="$S/cache"; mkdir -p "$BACKEND_CACHE_DIR"
export BACKEND_CACHE_SALT="$F1"

TD="$S/test"; mkdir -p "$TD"
printf 'backend\n'      > "$TD/backend.zig"
printf 'build_backend\n' > "$TD/build_backend.zig"
printf 'emitted\n'      > "$TD/backend_output_emitted.zig"

K=$(backend_cache_key "$TD")
eq "is deterministic" "$K" "$(backend_cache_key "$TD")"
printf '// comment-only line\n' >> "$TD/backend_output_emitted.zig"
eq "comment-only lines are stripped" "$K" "$(backend_cache_key "$TD")"
printf 'emitted // trailing\n' > "$TD/backend_output_emitted.zig"
neq "trailing comments are kept (no string-literal collision)" "$K" "$(backend_cache_key "$TD")"
printf 'emitted\n' > "$TD/backend_output_emitted.zig"
(export BACKEND_CACHE_SALT=0000000000000000; backend_cache_key "$TD" > "$S/other")
neq "a different salt gives a different key" "$K" "$(cat "$S/other")"

# ── hit path: restore, no build, and record the use ─────────────────────────
echo "hit path:"
head -c 4096 /dev/urandom > "$BACKEND_CACHE_DIR/$K"
touch -t 202601010101 "$BACKEND_CACHE_DIR/$K"
mt0=$(mt "$BACKEND_CACHE_DIR/$K")
BACKEND_CACHE_HIT=false
backend_stage_or_build "$TD" build_backend.zig "$K" >/dev/null 2>&1
eq "reports a hit" "true" "$BACKEND_CACHE_HIT"
cmp -s "$BACKEND_CACHE_DIR/$K" "$TD/zig-out/bin/backend" \
    && ok "restored bytes match the entry" || bad "restored bytes differ"
[ -x "$TD/zig-out/bin/backend" ] && ok "restored file is executable" || bad "restored file is not executable"
[ -f "$TD/compile_backend.err" ] && bad "a build ran on a hit" || ok "no build ran on a hit"
[ "$(mt "$BACKEND_CACHE_DIR/$K")" -gt "$mt0" ] \
    && ok "the hit advanced the entry mtime (use is recorded for LRU)" \
    || bad "entry mtime not advanced by the hit"

echo "store path:"
printf 'built backend\n' > "$TD/backend"
BACKEND_CACHE_HIT=false
K2=$(backend_cache_key "$TD")
eq "key ignores the built binary" "$K" "$K2"
printf 'backend v2\n' > "$TD/backend.zig"
K2=$(backend_cache_key "$TD")
neq "an input change gives a fresh key" "$K" "$K2"
backend_cache_store "$TD" "$K2"
[ -f "$BACKEND_CACHE_DIR/$K2" ] && ok "store wrote the entry" || bad "store wrote nothing"
cmp -s "$TD/backend" "$BACKEND_CACHE_DIR/$K2" && ok "stored bytes match the build" || bad "stored bytes differ"
before=$(mt "$BACKEND_CACHE_DIR/$K2")
BACKEND_CACHE_HIT=true
backend_cache_store "$TD" "$K2"
eq "store is a no-op on a hit" "$before" "$(mt "$BACKEND_CACHE_DIR/$K2")"

# ── prune: LRU to the cap, never inside the live window ─────────────────────
echo "prune:"
PD="$S/prune"; mkdir -p "$PD"
prune() { backend_cache_prune "$PD" "$1"; }
nfiles() { find "$PD" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' '; }
stamp() { printf '2026010%d0101' "$1"; }        # 12 digits: touch -t rejects anything else

for i in 1 2 3 4 5 6; do
    head -c 1048576 /dev/zero > "$PD/e$i"
    touch -t "$(stamp "$i")" "$PD/e$i"           # e1 oldest .. e6 newest, all past the window
done
: > "$PD/.stale.1.tmp"; touch -t 202601010001 "$PD/.stale.1.tmp"
: > "$PD/.live.2.tmp"                            # fresh residue: must be kept
mkdir -p "$PD/subdir"                            # not an entry: must be kept

prune 20971520                                   # 20 MiB cap, 6 MiB present
eq "under the cap: nothing evicted" "6" "$(nfiles)"
[ -f "$PD/.stale.1.tmp" ] && bad "stale staging residue was kept" || ok "stale staging residue swept"
[ -f "$PD/.live.2.tmp" ] && ok "fresh staging residue kept" || bad "fresh residue swept"
[ -d "$PD/subdir" ] && ok "subdirectory kept" || bad "subdirectory removed"

prune 3145728                                    # 3 MiB cap -> e1..e3 go, e4..e6 stay
eq "cap enforced by evicting the oldest" "3" "$(nfiles)"
eq "the boundary entry survived" "1" "$([ -f "$PD/e4" ] && echo 1 || echo 0)"
eq "the oldest entries went" "0" "$([ -f "$PD/e3" ] && echo 1 || echo 0)"
eq "the newest entry survived" "1" "$([ -f "$PD/e6" ] && echo 1 || echo 0)"

touch "$PD/e4"                                   # e4 is now the most recently used
prune 2097152                                    # room for 2 -> the oldest (e5) goes
eq "a used entry outlives one that is not" "1" "$([ -f "$PD/e4" ] && echo 1 || echo 0)"
eq "the next-oldest went instead" "0" "$([ -f "$PD/e5" ] && echo 1 || echo 0)"
eq "2 entries left" "2" "$(nfiles)"

prune 1                                          # tiny cap: only e4 is inside the window
eq "the in-window entry is protected" "1" "$([ -f "$PD/e4" ] && echo 1 || echo 0)"
eq "the aged entry is evicted instead" "0" "$([ -f "$PD/e6" ] && echo 1 || echo 0)"

backend_cache_prune "$S/does-not-exist" 1024; eq "missing dir is a no-op" "0" "$?"
ED="$S/empty"; mkdir -p "$ED"; backend_cache_prune "$ED" 0
eq "empty dir is a no-op" "0" "$?"

# `backend_cache_prune_once` targets $BACKEND_CACHE_DIR, so point it at the
# fixture before driving the disabled/enabled and once-per-shell paths.
BACKEND_CACHE_DIR="$PD"
echo "prune is skipped entirely while the cache is disabled:"
for i in 1 2 3; do
    head -c 1048576 /dev/zero > "$PD/off$i"
    touch -t "$(stamp "$i")" "$PD/off$i"
done
n_off=$(nfiles)
_BACKEND_CACHE_PRUNED=false
BACKEND_CACHE_MODE=off
KORU_BACKEND_CACHE_MAX_BYTES=1 backend_cache_prune_once
eq "nothing evicted with the cache off (even far over cap)" "$n_off" "$(nfiles)"
BACKEND_CACHE_MODE=on
_BACKEND_CACHE_PRUNED=false
KORU_BACKEND_CACHE_MAX_BYTES=1 backend_cache_prune_once
[ "$(nfiles)" -lt "$n_off" ] && ok "the same call bounds the dir once re-enabled" \
                             || bad "prune did not fire once re-enabled"
_BACKEND_CACHE_PRUNED=false
KORU_BACKEND_CACHE_MAX_BYTES=1 backend_cache_prune_once
eq "second call in one shell is skipped by the guard" "1" "$(nfiles)"

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]

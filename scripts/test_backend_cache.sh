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

# ── the closure: what a key may depend on ───────────────────────────────────
# A key must be COMPLETE (every file the backend embeds; an omission serves a
# stale backend) and MINIMAL (nothing else; an inclusion re-mints every cached
# backend for an edit that cannot change one). This pins both halves.
echo "closure:"
REPO="$S/repo"
TD="$S/test"
mkdir -p "$REPO/src" "$REPO/koru_std" "$TD"

printf 'pub const x = 1;\n' > "$REPO/src/linked.zig"
printf 'const l = @import("linked");\npub const y = l.x;\n' > "$REPO/src/relative_only.zig"
printf 'pub const z = 9;\n' > "$REPO/src/unlinked.zig"
printf 'pub const k = 3;\n' > "$REPO/koru_std/unlinked_module.kz"
# The traps a textual walk must not read as edges: a comment naming an import,
# and a string literal that ENDS in `@import(` — the exact shape at
# src/visitor_emitter.zig:4812.
printf 'const s = @import("std");\n// @import("a_comment_is_not_an_edge")\nconst t = "text ending in @import(";\n' > "$REPO/src/lexer_traps.zig"
printf 'const traps = @import("lexer_traps");\n' > "$REPO/src/uses_lexer_traps.zig"

printf 'const x = @import("linked");\n' > "$TD/backend.zig"
printf 'emitted\n' > "$TD/backend_output_emitted.zig"
cat > "$TD/build_backend.zig" <<EOF
const REL_TO_ROOT = "$REPO";
const std = @import("std");
pub fn build(b: *std.Build) void {
    const linked_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = REL_TO_ROOT ++ "/src/linked.zig" },
        .target = target,
        .optimize = optimize,
    });
    const relative_only_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = REL_TO_ROOT ++ "/src/relative_only.zig" },
        .target = target,
        .optimize = optimize,
    });
    const uses_lexer_traps_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = REL_TO_ROOT ++ "/src/uses_lexer_traps.zig" },
        .target = target,
        .optimize = optimize,
    });
    const backend_output_module = b.createModule(.{
        .root_source_file = b.path("backend_output_emitted.zig"),
        .target = target,
        .optimize = optimize,
    });
    backend_output_module.addImport("linked", linked_module);
}
EOF

export BACKEND_CACHE_MODE=on
export BACKEND_CACHE_DIR="$S/cache"
mkdir -p "$BACKEND_CACHE_DIR"

inputs=$(backend_cache_inputs "$TD" "$TD/build_backend.zig")
eq "a declared module root is in the closure"   1 "$(printf '%s\n' "$inputs" | grep -c 'src/linked.zig ' || true)"
eq "a relative @import is followed"             1 "$(printf '%s\n' "$inputs" | grep -c 'src/relative_only.zig ' || true)"
eq "a file nothing imports is excluded"         0 "$(printf '%s\n' "$inputs" | grep -c 'src/unlinked.zig ' || true)"
eq "an unlinked koru_std module is excluded"    0 "$(printf '%s\n' "$inputs" | grep -c 'unlinked_module.kz ' || true)"
eq "the test's own inputs are the caller's job" 0 "$(printf '%s\n' "$inputs" | grep -c 'backend_output_emitted.zig ' || true)"
eq "a comment naming @import is not an edge"    0 "$(printf '%s\n' "$inputs" | grep -c 'a_comment_is_not_an_edge' || true)"
eq "the file holding the traps is still walked" 1 "$(printf '%s\n' "$inputs" | grep -c 'src/uses_lexer_traps.zig ' || true)"

echo "the key moves with linked content, and only with linked content:"
K=$(backend_cache_key "$TD" "$TD/build_backend.zig")
[ -n "$K" ] && ok "the key is computable" || bad "the key is empty"
eq "the key is deterministic" "$K" "$(backend_cache_key "$TD" "$TD/build_backend.zig")"

printf 'pub const z = 10;\n' > "$REPO/src/unlinked.zig"
eq "editing an unlinked file does NOT move the key" "$K" "$(backend_cache_key "$TD" "$TD/build_backend.zig")"

printf 'pub const k = 4;\n' > "$REPO/koru_std/unlinked_module.kz"
eq "editing an unlinked koru_std module does NOT move the key" "$K" "$(backend_cache_key "$TD" "$TD/build_backend.zig")"

printf 'const l = @import("linked");\npub const y = l.x + 1;\n' > "$REPO/src/relative_only.zig"
neq "editing a relatively-imported file DOES move the key" "$K" "$(backend_cache_key "$TD" "$TD/build_backend.zig")"
K=$(backend_cache_key "$TD" "$TD/build_backend.zig")

printf 'pub const x = 2;\n' > "$REPO/src/linked.zig"
neq "editing a linked root DOES move the key" "$K" "$(backend_cache_key "$TD" "$TD/build_backend.zig")"

# the staging site passes a BARE build-file name, relative to the test dir (it is
# handed to `zig build --build-file` after its own cd); a key that only accepted
# an absolute path silently disabled the whole cache in every suite run
K=$(backend_cache_key "$TD" "$TD/build_backend.zig")
eq "a bare build-file name resolves against the test dir" "$K" "$(backend_cache_key "$TD" build_backend.zig)"

printf 'emitted\n// a comment-only line\n' > "$TD/backend_output_emitted.zig"
H=$(backend_cache_key "$TD" "$TD/build_backend.zig")
printf 'emitted\n' > "$TD/backend_output_emitted.zig"
eq "comment-only lines in the emitted handlers are stripped" "$H" "$(backend_cache_key "$TD" "$TD/build_backend.zig")"

echo "an unprovable closure keys nothing (never a partial key):"
BROKEN="$S/broken"; mkdir -p "$BROKEN"
printf 'const x = @import("does_not_exist");\n' > "$BROKEN/backend.zig"
printf 'e\n' > "$BROKEN/backend_output_emitted.zig"
printf 'const REL_TO_ROOT = "%s";\n' "$REPO" > "$BROKEN/build_backend.zig"
eq "unresolvable import" "" "$(backend_cache_key "$BROKEN" "$BROKEN/build_backend.zig" 2>/dev/null)"

NL="$S/nonliteral"; mkdir -p "$NL"
printf 'const n = "x";\nconst m = @import(n);\n' > "$NL/backend.zig"
printf 'e\n' > "$NL/backend_output_emitted.zig"
printf 'const REL_TO_ROOT = "%s";\n' "$REPO" > "$NL/build_backend.zig"
eq "non-literal @import" "" "$(backend_cache_key "$NL" "$NL/build_backend.zig" 2>/dev/null)"

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
K=$(backend_cache_key "$TD" "$TD/build_backend.zig")
eq "the default build file gives the same key" "$K" "$(backend_cache_key "$TD")"
K2=$(backend_cache_key "$TD")
printf 'built backend again\n' > "$TD/backend"
eq "key ignores the built binary" "$K2" "$(backend_cache_key "$TD")"
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

touch "$PD/.inputs.12345"                            # the per-run closure file's shape
prune 20971520                                   # 20 MiB cap, 6 MiB present
eq "under the cap: nothing evicted" "6" "$(nfiles)"
[ -f "$PD/.stale.1.tmp" ] && bad "stale staging residue was kept" || ok "stale staging residue swept"
[ -f "$PD/.live.2.tmp" ] && ok "fresh staging residue kept" || bad "fresh residue swept"
[ -d "$PD/subdir" ] && ok "subdirectory kept" || bad "subdirectory removed"

prune 3145728                                    # 3 MiB cap -> e1..e3 go, e4..e6 stay
eq "cap enforced by evicting the oldest" "3" "$(nfiles)"
eq "a dotfile is not an eviction candidate" "1" "$([ -f "$PD/.inputs.12345" ] && echo 1 || echo 0)"
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

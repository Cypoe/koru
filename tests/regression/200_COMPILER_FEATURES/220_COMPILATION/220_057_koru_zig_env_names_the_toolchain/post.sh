#!/bin/bash
# KORU_ZIG names the zig binary every toolchain spawn uses — the two-zigs
# problem: a suite's zig (0.16) differs from the one koruc pins (0.15.2).
# Wrap it, compile, and prove the wrapper saw BOTH halves of the pipeline:
# koruc's own backend build AND the backend's emitted-program build.
set -e
cd "$(dirname "$0")"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$KORU_INPUT" "$work/input.k"
cd "$work"

cat > zig-wrapper <<'SH'
#!/bin/sh
echo "hit $*" >> "$KORU_ZIG_LOG"
exec zig "$@"
SH
chmod +x zig-wrapper

KORU_ZIG="$work/zig-wrapper" KORU_ZIG_LOG="$work/wrapper.log" \
    koruc -OReleaseFast -o named_exe input.k > build.out 2>&1 || {
    echo "FAIL: koruc under KORU_ZIG did not build"; tail -10 build.out; exit 1; }

[ -s wrapper.log ] || { echo "FAIL: wrapper never invoked — KORU_ZIG ignored"; exit 1; }
grep -q "build-exe" wrapper.log || {
    echo "FAIL: emitted-program build did not go through KORU_ZIG"; cat wrapper.log; exit 1; }

out=$(./named_exe)
[ "$out" = "env-ok" ] || { echo "FAIL: named_exe printed '$out'"; exit 1; }

#!/bin/bash
# -o is the CLI contract Makefiles and callers rely on: the binary lands at
# the name given, not a.out. Compile the same input with -o and run what
# came out — asserting on the name alone would pass a flag that writes
# nothing runnable.
set -e
cd "$(dirname "$0")"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$KORU_INPUT" "$work/input.k"
cd "$work"

koruc -OReleaseFast -o named_exe input.k > build.out 2>&1 || {
    echo "FAIL: koruc -o did not build"; tail -10 build.out; exit 1; }

[ -x ./named_exe ] || { echo "FAIL: named_exe missing or not executable"; ls; exit 1; }
[ ! -e ./a.out ] || { echo "FAIL: a.out was written anyway — -o did not take"; exit 1; }

out=$(./named_exe)
[ "$out" = "named-exe" ] || { echo "FAIL: named_exe printed '$out'"; exit 1; }

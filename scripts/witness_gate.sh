#!/bin/bash
# Witness oracle gate — Role B for the witness checker.
#
# The Lean checker (verify/witness/WitnessCheck.lean) re-decides every
# `[witness] site …` line the compiler printed; verdicts must match on every
# line. The forged corpus must be rejected line-for-line (N4). A missing Lean
# toolchain is a FAIL, never a skip: an oracle that did not run did not pass.
#
# Usage: scripts/witness_gate.sh [corpus ...]
#   default corpus: 690_364's backend.err (run the regression test first).
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LEAN="${KORU_LEAN:-/home/cypoe/.elan/toolchains/leanprover--lean4---v4.31.0/bin/lean}"
DIR="$ROOT/verify/witness"
if [ ! -x "$LEAN" ]; then
    echo "FAIL: lean not found at $LEAN (set KORU_LEAN)"
    exit 1
fi
if [ $# -eq 0 ]; then
    set -- "$ROOT/tests/regression/600_STDLIB/690_STORE/690_364_witness_marks_ride_lowered_stored_writes/backend.err"
fi
cd "$DIR" || exit 1
fail=0
"$LEAN" WitnessCheck.lean >/dev/null 2>"$DIR/.theorems.err" || fail=1
if [ -s "$DIR/.theorems.err" ]; then
    echo "FAIL: Role A — WitnessCheck.lean does not check:"
    cat "$DIR/.theorems.err"
    fail=1
fi
rm -f "$DIR/.theorems.err"
"$LEAN" --run WitnessCheck.lean golden.txt | tail -1 || fail=1
for corpus in "$@"; do
    if [ ! -f "$corpus" ]; then
        echo "FAIL: corpus missing: $corpus"
        fail=1
        continue
    fi
    "$LEAN" --run WitnessCheck.lean "$corpus" || fail=1
done
"$LEAN" --run WitnessCheck.lean --forged forged.txt | tail -1 || fail=1
if [ $fail -eq 0 ]; then echo "witness gate: PASS"; else echo "witness gate: FAIL"; fi
exit $fail

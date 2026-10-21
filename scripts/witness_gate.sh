#!/bin/bash
# Witness oracle gate — Role B for the witness checker.
#
# The Lean checker (verify/witness/WitnessCheck.lean) re-decides every
# `[witness] site …` line the compiler printed; verdicts must match on every
# line. The forged corpus must be rejected line-for-line (N4). A missing Lean
# toolchain is a FAIL, never a skip: an oracle that did not run did not pass.
#
# Usage: scripts/witness_gate.sh [corpus ...]
#   default corpus: 690_378's backend.err (run the regression test first).
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lean_resolve.sh"
resolve_lean
DIR="$ROOT/verify/witness"
if [ ! -x "$LEAN" ]; then
    echo "FAIL: lean not found at $LEAN (set KORU_LEAN)"
    exit 1
fi
if [ $# -eq 0 ]; then
    set -- "$ROOT/tests/regression/600_STDLIB/690_STORE/690_378_witness_marks_ride_lowered_stored_writes/backend.err"
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
# Corpus-drift control: a well-formed-but-unbalanced census must FAIL a
# conformance batch — rejection is the expected verdict, never a skip.
if "$LEAN" --run WitnessCheck.lean drift.txt >/dev/null 2>&1; then
    echo "FAIL: drift corpus accepted (census unbalanced but passed)"
    fail=1
fi
if [ $fail -eq 0 ]; then echo "witness gate: PASS"; else echo "witness gate: FAIL"; fi
exit $fail

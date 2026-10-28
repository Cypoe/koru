#!/bin/bash
# Claims oracle gate — Role B for the claims ledger checker.
#
# The Lean checker (verify/claims/ClaimsCheck.lean) re-decides every
# `[claim-check]`/`[claim-census]` line the claims pass printed under
# std/witness:enforce; the ledger must be balanced. The forged corpus
# must be rejected line-for-line (N4). A missing Lean toolchain is a
# FAIL, never a skip: an oracle that did not run did not pass.
#
# Usage: scripts/claims_gate.sh [corpus ...]
#   default corpus: 675_036's backend.err (run the regression test first).
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lean_resolve.sh"
resolve_lean
DIR="$ROOT/verify/claims"
if [ ! -x "$LEAN" ]; then
    echo "FAIL: lean not found at $LEAN (set KORU_LEAN)"
    exit 1
fi
if [ $# -eq 0 ]; then
    set -- "$ROOT/tests/regression/600_STDLIB/675_INVARIANTS/675_036_claim_verdicts_ledger/backend.err"
fi
# Corpus args resolve against the caller's cwd — absolutize before cd.
abs=()
for corpus in "$@"; do abs+=("$(readlink -f "$corpus")"); done
set -- "${abs[@]}"
cd "$DIR" || exit 1
fail=0
"$LEAN" ClaimsCheck.lean >/dev/null 2>"$DIR/.theorems.err" || fail=1
if [ -s "$DIR/.theorems.err" ]; then
    echo "FAIL: Role A — ClaimsCheck.lean does not check:"
    cat "$DIR/.theorems.err"
    fail=1
fi
rm -f "$DIR/.theorems.err"
"$LEAN" --run ClaimsCheck.lean golden.txt | tail -1 || fail=1
for corpus in "$@"; do
    if [ ! -f "$corpus" ]; then
        echo "FAIL: corpus missing: $corpus"
        fail=1
        continue
    fi
    "$LEAN" --run ClaimsCheck.lean "$corpus" || fail=1
done
"$LEAN" --run ClaimsCheck.lean --forged forged.txt | tail -1 || fail=1
# Corpus-drift control: a well-formed-but-unbalanced census must FAIL a
# conformance batch — rejection is the expected verdict, never a skip.
if "$LEAN" --run ClaimsCheck.lean drift.txt >/dev/null 2>&1; then
    echo "FAIL: drift corpus accepted (census unbalanced but passed)"
    fail=1
fi
# Semantic-forgery control: well-formed lines whose committed evidence
# does not entail the printed `proven` — the FM re-decision must catch
# what shape-checking alone cannot.
if "$LEAN" --run ClaimsCheck.lean tampered.txt >/dev/null 2>&1; then
    echo "FAIL: tampered corpus accepted (evidence does not entail proven)"
    fail=1
fi
if [ $fail -eq 0 ]; then echo "claims gate: PASS"; else echo "claims gate: FAIL"; fi
exit $fail

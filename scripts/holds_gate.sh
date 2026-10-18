#!/bin/bash
# Holds-log oracle gate — Role B for the custody ledger checker.
#
# The Lean checker (verify/holds/HoldsCheck.lean) re-decides every line a
# world-mounted bridge appended to holds.log: session spans, mint→release
# pairing, died-holding, and every malformed class — independent code over
# the record the pool's on_custody callback wrote. A missing Lean toolchain
# is a FAIL, never a skip: an oracle that did not run did not pass.
#
# Role A: `lean HoldsCheck.lean` IS the check — every theorem is re-decided
#         by the Lean kernel and the fixture corpus (golden + eleven forged
#         shapes) is pinned by native_decide theorems, so a clean exit is
#         the whole warrant; any warning is a FAIL, not a skip.
# Role B: each corpus argument is a real holds.log a test produced; the
#         checker must print `clean` and exit 0. A missing corpus FAILs —
#         a HOLDS_CHECK-marked test that wrote no record is a broken leg,
#         not a vacuous pass.
#
# Usage: scripts/holds_gate.sh <holds.log> [<holds.log> ...]
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lean_resolve.sh"
resolve_lean
DIR="$ROOT/verify/holds"
if [ ! -x "$LEAN" ]; then
    echo "FAIL: lean not found at $LEAN (set KORU_LEAN)"
    exit 1
fi
cd "$DIR" || exit 1
fail=0
"$LEAN" HoldsCheck.lean >/dev/null 2>"$DIR/.theorems.err" || fail=1
if [ -s "$DIR/.theorems.err" ]; then
    echo "FAIL: Role A — HoldsCheck.lean does not check:"
    cat "$DIR/.theorems.err"
    fail=1
fi
rm -f "$DIR/.theorems.err"
if [ $# -eq 0 ]; then
    echo "FAIL: no corpus — a marked test must produce a holds.log"
    fail=1
fi
for corpus in "$@"; do
    if [ ! -f "$corpus" ]; then
        echo "FAIL: corpus missing: $corpus"
        fail=1
        continue
    fi
    "$LEAN" --run HoldsCheck.lean "$corpus" || fail=1
done
if [ $fail -eq 0 ]; then echo "holds gate: PASS"; else echo "holds gate: FAIL"; fi
exit $fail

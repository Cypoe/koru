#!/bin/bash
# Semantics kernel gate — Role A for verify/semantics/.
#
# FlowKernel.lean carries the mechanized flow-graph evaluator, its
# fixture evaluations (`by native_decide`), and its metatheorems
# (firstCont_fires_first, evalNode_mono). Compiling it IS the check:
# the theorems are re-decided by the Lean kernel, so `lean` exiting
# clean means every committed evaluation and proof held — and any
# warning or sorry is a FAIL, not a skip.
#
# Usage: scripts/semantics_gate.sh
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LEAN="${KORU_LEAN:-/home/cypoe/.elan/toolchains/leanprover--lean4---v4.31.0/bin/lean}"
DIR="$ROOT/verify/semantics"
if [ ! -x "$LEAN" ]; then
    echo "FAIL: lean not found at $LEAN (set KORU_LEAN)"
    exit 1
fi
fail=0
for f in "$DIR"/*.lean; do
    if ! "$LEAN" "$f" >/dev/null 2>"$DIR/.check.err"; then
        fail=1
    fi
    if [ -s "$DIR/.check.err" ]; then
        echo "FAIL: $(basename "$f") does not check clean:"
        cat "$DIR/.check.err"
        fail=1
    fi
    rm -f "$DIR/.check.err"
done
if [ $fail -eq 0 ]; then echo "semantics gate: PASS"; else echo "semantics gate: FAIL"; fi
exit $fail

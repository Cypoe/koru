#!/bin/bash
# Semantics kernel gate — verify/semantics/, Roles A and B.
#
# FlowKernel.lean carries the mechanized flow-graph evaluator, its
# fixture evaluations (`by native_decide`), and its metatheorems
# (firstCont_fires_first, run_mono). FlowCheck.lean is the corpus-facing
# consumer: it parses emitted `[flow-eval]` s-expression claims and
# re-decides them against the kernel.
#
# Role A: `lean` compiling each file IS the check — the theorems are
#         re-decided by the Lean kernel, so a clean exit means every
#         committed evaluation and proof held; any warning or sorry is
#         a FAIL, not a skip.
# Role B: FlowCheck runs the three corpora — golden must MATCH every
#         claim, forged must REJECT every line, drift must FAIL the
#         batch (duplicate claims are dishonest accounting).
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
cd "$DIR" || exit 1
# Role A — every .lean checks clean. FlowKernel.olean is built first so
# `import FlowKernel` resolves through LEAN_PATH.
if ! "$LEAN" -o FlowKernel.olean FlowKernel.lean >/dev/null 2>.check.err; then
    fail=1
fi
if [ -s .check.err ]; then
    echo "FAIL: FlowKernel.lean does not check clean:"
    cat .check.err
    fail=1
fi
rm -f .check.err
for f in *.lean; do
    if ! LEAN_PATH="$DIR" "$LEAN" "$f" >/dev/null 2>.check.err; then
        fail=1
    fi
    if [ -s .check.err ]; then
        echo "FAIL: $f does not check clean:"
        cat .check.err
        fail=1
    fi
    rm -f .check.err
done
# Role B — corpus conformance. Golden must match, forged must reject,
# drift must fail the batch.
if ! LEAN_PATH="$DIR" "$LEAN" --run FlowCheck.lean golden.txt | tail -1; then
    fail=1
fi
if ! LEAN_PATH="$DIR" "$LEAN" --run FlowCheck.lean --forged forged.txt | tail -1; then
    fail=1
fi
if LEAN_PATH="$DIR" "$LEAN" --run FlowCheck.lean drift.txt >/dev/null 2>&1; then
    echo "FAIL: drift corpus accepted (duplicate claims but passed)"
    fail=1
fi
rm -f FlowKernel.olean FlowCheck.olean FlowCheck.c
if [ $fail -eq 0 ]; then echo "semantics gate: PASS"; else echo "semantics gate: FAIL"; fi
exit $fail

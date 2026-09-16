#!/bin/bash
# The program refuses (orphan join + wait-without-live), but `koruc explain`
# still runs on the pre-transform tree and reports WHY — the same refusal
# reasons the transforms raise, as report rows.
set -e

echo "=== koruc explain on a refusing program ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/pump" || { echo "FAIL: pump report missing"; exit 1; }
echo "$TEXT" | grep -q "no pump named 'ghost'"            || { echo "FAIL: orphan join not reported";     exit 1; }
echo "$TEXT" | grep -q "needs \`! live\` beside it"        || { echo "FAIL: wait/live refusal not reported"; exit 1; }
echo "$TEXT" | grep -q "j0.status = refused"               || { echo "FAIL: refused status not typed";    exit 1; }

echo "=== PASS: explain reports pump refusals ==="

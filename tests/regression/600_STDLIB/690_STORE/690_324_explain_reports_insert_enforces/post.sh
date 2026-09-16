#!/bin/bash
# `koruc explain` on a refined-member store: std/store's facet row names the
# enforcement verdict — `insert enforces them` — and the declared count is
# the same metFields fold the generated `?!violated` guards read.
set -e

echo "=== koruc explain (text) ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/store"                                  || { echo "FAIL: store report missing";       exit 1; }
echo "$TEXT" | grep -q "facets_declared = 1"                           || { echo "FAIL: facet count missing";        exit 1; }
echo "$TEXT" | grep -q "insert enforces them"                          || { echo "FAIL: enforcement verdict missing"; exit 1; }
if echo "$TEXT" | grep -q "does NOT enforce"; then
    echo "FAIL: the does-not-enforce row is stale — insert enforces"; exit 1
fi

echo "=== koruc explain json (typed) ==="
JSON=$(koruc "$KORU_INPUT" explain json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"facets_declared":1'                           || { echo "FAIL: facet count not typed";      exit 1; }

echo "=== PASS: explain reports insert enforcement ==="

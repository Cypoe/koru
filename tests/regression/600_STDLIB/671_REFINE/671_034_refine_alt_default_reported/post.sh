#!/bin/bash
# `koruc explain` on a field whose disjunction marks a fallback: the set is
# spelled with its `*`, the effect is `refuse` (push judges membership), and
# the default is reported as DECLARED with the reader it waits for named.
# `facets_enforced` counts the guard, not the fallback.
set -e

echo "=== koruc explain (text) ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/refine"                      || { echo "FAIL: refine report missing";  exit 1; }
echo "$TEXT" | grep -q "mode: i64 & \*1 | 2 | 3 — refuse"   || { echo "FAIL: set not spelled with its default"; exit 1; }
echo "$TEXT" | grep -q "mode.effect = refuse"               || { echo "FAIL: effect missing";         exit 1; }
echo "$TEXT" | grep -q "mode.default = 1"                   || { echo "FAIL: default row missing";    exit 1; }
echo "$TEXT" | grep -q "marks the fallback"                 || { echo "FAIL: fallback not explained"; exit 1; }
echo "$TEXT" | grep -q "facets_enforced = 1"                || { echo "FAIL: guard not counted";      exit 1; }

echo "=== koruc explain json (typed) ==="
JSON=$(koruc "$KORU_INPUT" explain json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"mode.default":1'                    || { echo "FAIL: default not typed";      exit 1; }
echo "$JSON" | grep -q '"mode.effect":"refuse"'             || { echo "FAIL: effect not typed";       exit 1; }
echo "$JSON" | grep -q '"facets_enforced":1'                || { echo "FAIL: count not typed";        exit 1; }

echo "=== PASS: the catalog reports the fallback as declared ==="

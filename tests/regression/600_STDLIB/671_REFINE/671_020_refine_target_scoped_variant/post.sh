#!/bin/bash
# `koruc explain` reports each refine scope as its own section: the
# universal facet from unscoped blocks (contributors = 1), and the
# `|fpga` facet from the universal + scoped fold (contributors = 2).
set -e

echo "=== koruc explain (text) ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/refine"              || { echo "FAIL: refine report missing";        exit 1; }
echo "$TEXT" | grep -q "input:Sample|fpga"          || { echo "FAIL: scoped section missing";       exit 1; }
echo "$TEXT" | grep -q "value.meet = i64 & >=0 & <=255" || { echo "FAIL: scoped meet missing";    exit 1; }
echo "$TEXT" | grep -q "contributors = 2"           || { echo "FAIL: scoped fold count missing";    exit 1; }

echo "=== koruc explain json (typed) ==="
JSON=$(koruc "$KORU_INPUT" explain json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"contributors":2'           || { echo "FAIL: scoped fold not typed";        exit 1; }
echo "$JSON" | grep -q '"value.effect":"refuse"'    || { echo "FAIL: scoped effect missing";        exit 1; }

echo "=== PASS: scoped refine reports as its own facet ==="

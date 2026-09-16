#!/bin/bash
# `koruc explain` gathers [explainer] reports: std/store reports the folded
# composition (capacity, members, interceptor arms, site counts) and the
# facet-honesty row — declared on the member proto, unchecked at insert.
set -e

echo "=== koruc explain (text) ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/store"                             || { echo "FAIL: store report missing";     exit 1; }
echo "$TEXT" | grep -q "capacity = 8"                           || { echo "FAIL: capacity missing";         exit 1; }
echo "$TEXT" | grep -q "columns = 2"                            || { echo "FAIL: member count missing";     exit 1; }
echo "$TEXT" | grep -q "left: Limb"                             || { echo "FAIL: member spelling missing";  exit 1; }
echo "$TEXT" | grep -q "inserts = 1"                            || { echo "FAIL: insert count missing";     exit 1; }
echo "$TEXT" | grep -q "queries = 1"                            || { echo "FAIL: query count missing";      exit 1; }
echo "$TEXT" | grep -q "facets_declared = 2"                    || { echo "FAIL: facet count missing";      exit 1; }
echo "$TEXT" | grep -q "does NOT enforce"                       || { echo "FAIL: facet honesty missing";    exit 1; }

echo "=== witness hashes + at resolution ==="
echo "$TEXT" | grep -qE "inserts = 1 \[[0-9a-z]+\]"             || { echo "FAIL: insert witness missing";   exit 1; }
HASH=$(echo "$TEXT" | grep -oE "inserts = 1 \[[0-9a-z]+\]" | grep -oE "\[[0-9a-z]+\]" | tr -d '[]')
AT=$(koruc "$KORU_INPUT" at "$HASH" 2>&1)
echo "$AT"
echo "$AT" | grep -q "std.store:insert"                        || { echo "FAIL: at missed the insert site"; exit 1; }
echo "$AT" | grep -q "input.k"                                 || { echo "FAIL: at lost the file";         exit 1; }
koruc "$KORU_INPUT" at "${HASH}zz" 2>&1 | grep -q "tail drifted" || { echo "FAIL: drifted tail not absorbed"; exit 1; }

echo "=== koruc explain json (typed) ==="
JSON=$(koruc "$KORU_INPUT" explain json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"capacity":8'         || { echo "FAIL: capacity not typed";   exit 1; }
echo "$JSON" | grep -q '"columns":2'          || { echo "FAIL: columns not typed";    exit 1; }
echo "$JSON" | grep -q '"inserts":1'          || { echo "FAIL: inserts not typed";    exit 1; }
echo "$JSON" | grep -q '"facets_declared":2'  || { echo "FAIL: facets not typed";     exit 1; }

echo "=== PASS: explain reports the store composition ==="

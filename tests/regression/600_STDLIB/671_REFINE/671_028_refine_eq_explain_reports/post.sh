#!/bin/bash
# `koruc explain` on an equality-refined field: std/refine spells the `==N`
# atom and reports its effect, std/list reports the same field as enforced.
# The catalog cannot call a field declared-only while push guards it.
set -e

echo "=== koruc explain (text) ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/refine"                 || { echo "FAIL: refine report missing";      exit 1; }
echo "$TEXT" | grep -q "input:Server"                 || { echo "FAIL: section heading missing";     exit 1; }
echo "$TEXT" | grep -q "port: i64 & ==8080 — refuse"  || { echo "FAIL: eq atom not spelled";        exit 1; }
echo "$TEXT" | grep -q "port.effect = refuse"         || { echo "FAIL: eq effect missing";          exit 1; }
echo "$TEXT" | grep -q "host.effect = declared only"  || { echo "FAIL: plain field effect missing"; exit 1; }
echo "$TEXT" | grep -q "📖 std/list"                  || { echo "FAIL: list report missing";        exit 1; }
echo "$TEXT" | grep -q "port.enforced = refuse"       || { echo "FAIL: enforcement row missing";    exit 1; }
echo "$TEXT" | grep -q "facets_enforced = 1"          || { echo "FAIL: enforcement count missing";  exit 1; }

echo "=== koruc explain json (typed) ==="
JSON=$(koruc "$KORU_INPUT" explain json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"port.effect":"refuse"'       || { echo "FAIL: eq effect not typed";        exit 1; }
echo "$JSON" | grep -q '"port.enforced":"refuse"'     || { echo "FAIL: enforcement not typed";      exit 1; }
echo "$JSON" | grep -q '"facets_enforced":1'          || { echo "FAIL: count not typed";            exit 1; }

echo "=== PASS: explain reports the equality atom ==="

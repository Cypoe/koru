#!/bin/bash
# `koruc explain` gathers [explainer] reports: std/refine reports the met
# facet (declared base, resolved terminal scalar, effect), std/list
# reports what push enforces on it. Asserted in text rows and the typed
# json catalog — integers stay integers, strings stay quoted.
set -e

echo "=== koruc explain (text) ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/refine"              || { echo "FAIL: refine report missing";      exit 1; }
echo "$TEXT" | grep -q "input:Server"              || { echo "FAIL: section heading missing";     exit 1; }
echo "$TEXT" | grep -q "contributors = 1"          || { echo "FAIL: contributor count missing";   exit 1; }
echo "$TEXT" | grep -q "port.scalar = i64"         || { echo "FAIL: terminal resolution missing"; exit 1; }
echo "$TEXT" | grep -q "port.effect = refuse"      || { echo "FAIL: bound effect missing";        exit 1; }
echo "$TEXT" | grep -q "gain.effect = saturate"    || { echo "FAIL: clamp effect missing";        exit 1; }
echo "$TEXT" | grep -q "host.effect = declared only" || { echo "FAIL: plain field effect missing"; exit 1; }
echo "$TEXT" | grep -q "📖 std/list"               || { echo "FAIL: list report missing";         exit 1; }
echo "$TEXT" | grep -q "facets_enforced = 2"       || { echo "FAIL: enforcement count missing";   exit 1; }

echo "=== koruc explain json (typed) ==="
JSON=$(koruc "$KORU_INPUT" explain json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"contributors":1'            || { echo "FAIL: contributor count not typed"; exit 1; }
echo "$JSON" | grep -q '"port.scalar":"i64"'         || { echo "FAIL: resolved scalar missing";     exit 1; }
echo "$JSON" | grep -q '"port.effect":"refuse"'      || { echo "FAIL: refuse effect missing";       exit 1; }
echo "$JSON" | grep -q '"gain.effect":"saturate"'    || { echo "FAIL: saturate effect missing";     exit 1; }
echo "$JSON" | grep -q '"facets_enforced":2'         || { echo "FAIL: enforcement not typed";       exit 1; }

echo "=== PASS: explain reports declared + enforced facets ==="

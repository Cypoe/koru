#!/bin/bash
# `koruc explain` gathers [explainer] reports: std/pump reports the folded
# composition — participants in join order, verbs per join, drain and idle
# policy. Asserted in text rows and the typed json catalog.
set -e

echo "=== koruc explain (text) ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/pump"                          || { echo "FAIL: pump report missing";      exit 1; }
echo "$TEXT" | grep -q "participants = 1"                    || { echo "FAIL: participant count missing"; exit 1; }
echo "$TEXT" | grep -q "drained_arm = true"                  || { echo "FAIL: drained arm missing";       exit 1; }
echo "$TEXT" | grep -q "run = true"                          || { echo "FAIL: run state missing";         exit 1; }
echo "$TEXT" | grep -q "drains = true"                       || { echo "FAIL: drain policy missing";      exit 1; }
echo "$TEXT" | grep -q "idle = union wait over 1 interest"   || { echo "FAIL: idle policy missing";       exit 1; }
echo "$TEXT" | grep -q "j0.step = input:step"                || { echo "FAIL: step callee missing";       exit 1; }
echo "$TEXT" | grep -q "j0.live = input:live"                || { echo "FAIL: live callee missing";       exit 1; }
echo "$TEXT" | grep -q "j0.wait = input:wait"                || { echo "FAIL: wait callee missing";       exit 1; }
echo "$TEXT" | grep -q "join #0: step + live + wait(i)"      || { echo "FAIL: join summary missing";      exit 1; }

echo "=== koruc explain json (typed) ==="
JSON=$(koruc "$KORU_INPUT" explain json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"participants":1'   || { echo "FAIL: count not typed";        exit 1; }
echo "$JSON" | grep -q '"drained_arm":true' || { echo "FAIL: drained not typed";      exit 1; }
echo "$JSON" | grep -q '"drains":true'      || { echo "FAIL: drain policy not typed"; exit 1; }
echo "$JSON" | grep -q '"j0.step":"input:step"' || { echo "FAIL: callee spelling missing"; exit 1; }

echo "=== PASS: explain reports the pump composition ==="

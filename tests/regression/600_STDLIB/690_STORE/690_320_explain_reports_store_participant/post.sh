#!/bin/bash
# `koruc explain` on a store-as-participant program: std/store reports the
# owned column, the interceptor arms, and the exposed pump verbs; std/pump
# resolves the generated callees to their synthesizer. Both halves of the
# generated-name channel are reported by the modules that own them.
set -e

echo "=== koruc explain (text) ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/store"                                    || { echo "FAIL: store report missing";    exit 1; }
echo "$TEXT" | grep -q "capacity = 4"                                  || { echo "FAIL: capacity missing";        exit 1; }
echo "$TEXT" | grep -q "columns = 1"                                   || { echo "FAIL: owned column missing";    exit 1; }
echo "$TEXT" | grep -q "Task<live!> — owned"                           || { echo "FAIL: owned mark missing";      exit 1; }
echo "$TEXT" | grep -q "interceptors = step, discharge, wait"          || { echo "FAIL: interceptor list missing"; exit 1; }
echo "$TEXT" | grep -q "pump participant — exposes tasks-step"         || { echo "FAIL: participant row missing"; exit 1; }
echo "$TEXT" | grep -q "tasks-wait"                                    || { echo "FAIL: wait verb missing";       exit 1; }
echo "$TEXT" | grep -q "📖 std/pump"                                    || { echo "FAIL: pump report missing";     exit 1; }
echo "$TEXT" | grep -q "tasks-step ← synthesized by std/store:new(tasks)" || { echo "FAIL: synthesized callee missing"; exit 1; }
echo "$TEXT" | grep -q "drains = true"                                 || { echo "FAIL: drain policy missing";    exit 1; }

echo "=== koruc explain json (typed) ==="
JSON=$(koruc "$KORU_INPUT" explain json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"capacity":4' || { echo "FAIL: capacity not typed"; exit 1; }
echo "$JSON" | grep -q '"drains":true' || { echo "FAIL: drains not typed";  exit 1; }

echo "=== PASS: explain reports the store participant ==="

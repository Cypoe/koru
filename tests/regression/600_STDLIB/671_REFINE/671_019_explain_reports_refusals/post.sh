#!/bin/bash
# The program refuses to compile (MUST_ERROR pins the KORU205) — but
# `koruc explain` runs INSTEAD of the pipeline, so it reports the same
# refusals as data: the orphaned anchor and the non-integer terminal bound.
set -e

echo "=== koruc explain on a refusing program ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/refine"                                            || { echo "FAIL: refine report missing";      exit 1; }
echo "$TEXT" | grep -q "input:Ghost"                                            || { echo "FAIL: orphan section missing";     exit 1; }
echo "$TEXT" | grep -q "refused: no std/proto declaration"                      || { echo "FAIL: orphan status missing";      exit 1; }
echo "$TEXT" | grep -q "refused: no declaration named 'Ghost'"                  || { echo "FAIL: orphan field status missing";exit 1; }
echo "$TEXT" | grep -q "resolves to 'string'"                                   || { echo "FAIL: terminal resolution missing";exit 1; }
echo "$TEXT" | grep -q "bounds and clamps refine integer scalars only"          || { echo "FAIL: non-int refusal missing";    exit 1; }

echo "=== PASS: explain reports refusals on a program that cannot compile ==="

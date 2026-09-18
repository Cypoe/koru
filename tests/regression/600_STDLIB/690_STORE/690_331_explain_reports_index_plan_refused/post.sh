#!/bin/bash
# `koruc explain` on a program whose index declaration refuses: the
# `status` row carries the transform's own refusal wording — the same
# "names no column" text the compiler emits — never a guessed index row.
set -e

echo "=== koruc explain (text) on a refusing program ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/store"                            || { echo "FAIL: store report missing";    exit 1; }
echo "$TEXT" | grep -q "status = refused:"                     || { echo "FAIL: refused status missing";  exit 1; }
echo "$TEXT" | grep -q "names no column"                       || { echo "FAIL: refusal wording drifted"; exit 1; }

echo "=== PASS: explain reports the refused index declaration ==="

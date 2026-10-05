#!/bin/bash
# `ready` is a liveness probe distinct from `check`: exit nonzero means
# present-but-unusable. The report must name the third state and must NOT
# print the all-clear while any dep sits in it.
set -e

OUT=$(koruc "$KORU_INPUT" deps 2>&1)

echo "$OUT" | grep -q "present-ready" || { echo "FAIL: present-ready dep missing"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "present-down.*installed, not ready" || { echo "FAIL: not-ready state unnamed"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "Installed but not ready" || { echo "FAIL: no not-ready summary"; echo "$OUT"; exit 1; }
if echo "$OUT" | grep -q "All system dependencies are installed"; then
    echo "FAIL: claimed all-clear with a not-ready dep"; echo "$OUT"; exit 1
fi
echo "PASS"

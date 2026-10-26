#!/bin/bash
# `koruc explain` must spell the relational row from the SAME fold the
# transform ran — the explainer and the transform share one meet, so
# the canonical `spend <= balance + margin` cannot drift from the
# marker.
set -e

TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "spend.meet = i64 & >=0 & spend <= balance + margin" || { echo "FAIL: relational row missing from the reported meet"; exit 1; }
echo "=== PASS: explain reports the relational meet ==="

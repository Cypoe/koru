#!/bin/bash
# The handler must observe the flag-gated build:config value, not an empty
# registry. `port=MISSING` under either build flag is the failure this pins.
set -e

DEV=$(koruc "$KORU_INPUT" cfg --build=dev 2>&1)
echo "$DEV" | grep -q "port=3000" || { echo "FAIL: dev did not resolve port=3000"; echo "$DEV"; exit 1; }

PROD=$(koruc "$KORU_INPUT" cfg --build=prod 2>&1)
echo "$PROD" | grep -q "port=80" || { echo "FAIL: prod did not resolve port=80"; echo "$PROD"; exit 1; }

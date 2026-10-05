#!/bin/bash
# The backend must compile: before the fix the comptime_flowN for
# `tag(second)|dev` emitted `tag_event.handler__dev(...)`, a member that does
# not exist because no `proc tag|dev` was declared. The handler also prints
# the variant back off the AST — the tag must survive as collector metadata.
set -e

OUT=$(koruc "$KORU_INPUT" seen 2>&1)
echo "$OUT" | grep -q "variant=dev" || { echo "FAIL: variant metadata lost"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "ok" || { echo "FAIL: command did not run"; echo "$OUT"; exit 1; }
echo "PASS"

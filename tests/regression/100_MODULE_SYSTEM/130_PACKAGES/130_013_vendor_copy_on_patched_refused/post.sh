#!/bin/bash
# `copy` on a patched tree must refuse and leave as-copied untouched.
# The program compiled (live matches as-compiled). Overwriting as-copied
# would launder the patch as a new upstream.

set -e
COPIED_BEFORE=$(python3 -c "import json; print(json.load(open('vendor.lock'))['bindings']['koru/vaxis']['as-copied']['tree'])")

OUT=$(koruc "$KORU_INPUT" vendor copy 2>&1) && RC=0 || RC=$?

[ "$RC" -ne 0 ] \
    || { echo "FAIL: vendor copy on patched tree exited 0"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "as-copied is never overwritten" \
    || { echo "FAIL: refusal did not name as-copied"; echo "$OUT"; exit 1; }

COPIED_AFTER=$(python3 -c "import json; print(json.load(open('vendor.lock'))['bindings']['koru/vaxis']['as-copied']['tree'])")
[ "$COPIED_BEFORE" = "$COPIED_AFTER" ] \
    || { echo "FAIL: as-copied changed ($COPIED_BEFORE -> $COPIED_AFTER)"; exit 1; }

echo "PASS: copy on patched refused; as-copied untouched"
exit 0

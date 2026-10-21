#!/bin/bash
# The diagnostic crossed the barrier iff the sink fired: koru-diagnostics.jsonl exists
# with a KORU040 row carrying file/line — the refusal on stderr AND the row
# are the same ParseError seen through two consumers.
set -u
cd "$(dirname "$0")"
fail() { echo "FAIL: $1"; exit 1; }

[ -f koru-diagnostics.jsonl ] || fail "koru-diagnostics.jsonl not produced — sink did not fire"
lines=$(wc -l < koru-diagnostics.jsonl | tr -d ' ')
[ "$lines" -ge 1 ] || fail "koru-diagnostics.jsonl exists but has no rows"
grep -q '"code":"KORU040"' koru-diagnostics.jsonl || fail "KORU040 row missing from koru-diagnostics.jsonl"
grep -q '"file":' koru-diagnostics.jsonl || fail "diagnostic row missing file field"
grep -q '"line":' koru-diagnostics.jsonl || fail "diagnostic row missing line field"

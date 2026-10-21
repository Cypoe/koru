#!/bin/bash
# The diagnostic crossed the barrier iff the sink fired — and the X:config
# block crossed it iff the row landed in the CONFIGURED file: custom-diag.db,
# not the builtin default. The refusal on stderr AND the row are the same
# ParseError seen through two consumers. The opt-in dep is also pinned: the
# generated build_backend.zig must carry the sqlite3 link.
set -u
cd "$(dirname "$0")"
fail() { echo "FAIL: $1"; exit 1; }

[ -f custom-diag.db ] || fail "custom-diag.db not produced — :config block did not reach the sink"
grep -q 'sqlite3' build_backend.zig || fail "build_backend.zig missing sqlite3 link requirement"
python3 -c '
import sqlite3
rows = sqlite3.connect("custom-diag.db").execute(
    "SELECT code, file, line, col, message, hint FROM diagnostics").fetchall()
assert any(r[0] == "KORU040" and "totally-bogus" in r[4] for r in rows), \
    f"no KORU040 row: {rows!r}"
' || fail "KORU040 row missing from custom-diag.db"

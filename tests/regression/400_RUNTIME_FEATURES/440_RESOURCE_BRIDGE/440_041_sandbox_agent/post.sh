#!/bin/bash
TD="tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_041_sandbox_agent"
[ -d "$TD" ] || TD="."
ok=1

# Strict transcript: seeded-hex dir handles normalize before the diff.
sed -E 's/h:Dir:[0-9a-f]{6}/h:Dir:HEX/' actual.txt > actual.norm.txt
diff -u expected.transcript actual.norm.txt || { echo "transcript drifted"; ok=0; }

[ -f "$TD/world/sweep.k" ] || { echo "sweep.k was not persisted"; ok=0; }
grep -q 'sweep = write(d, path, content: text)' "$TD/world/sweep.k" 2>/dev/null || { echo "persisted sweep.k content wrong"; ok=0; }
[ -f "$TD/sandbox/invented.txt" ] || { echo "sweep never wrote its file"; ok=0; }
rm -rf "$TD/world" "$TD/sandbox/invented.txt" actual.norm.txt
[ "$ok" -eq 1 ] || exit 1

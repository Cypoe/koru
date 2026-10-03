#!/bin/bash
TD="tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_041_sandbox_agent"
[ -d "$TD" ] || TD="."
ok=1
[ -f "$TD/world/sweep.k" ] || { echo "sweep.k was not persisted"; ok=0; }
grep -q 'sweep = write(path, text)' "$TD/world/sweep.k" 2>/dev/null || { echo "persisted sweep.k content wrong"; ok=0; }
[ -f "$TD/sandbox/invented.txt" ] || { echo "sweep never wrote its file"; ok=0; }
rm -rf "$TD/world" "$TD/sandbox/invented.txt"
[ "$ok" -eq 1 ] || exit 1

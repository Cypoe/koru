#!/bin/bash
# `koruc at` reports the line the user wrote, for every site class: a
# `|>`-chained site lands on the line its own `|>` stands on (not the chain
# head's), nested arm sites on their `|`/`!` line, and a flow's hash reports
# the flow head's own line. The bootstrap `import std/compiler` the frontend
# prepends is invisible in all of it. `--ast-json` emits the same
# user-coordinate lines for continuation locations.
set -e

echo "=== witness hash from explain ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
QHASH=$(echo "$TEXT" | grep -oE "query\[0\] = ! first p — index lookup on key \[[0-9a-z]+\]" | grep -oE "\[[0-9a-z]+\]" | tail -1 | tr -d '[]')
[ -n "$QHASH" ] || { echo "FAIL: no query witness hash"; exit 1; }

echo "=== chained |> site reports its own link line ==="
QAT=$(koruc "$KORU_INPUT" at "$QHASH" 2>&1)
echo "$QAT"
echo "$QAT" | grep -q "std.store:query.*input.k:21"     || { echo "FAIL: |> query link not reported on line 21";  exit 1; }
echo "$QAT" | grep -q "std.io:print.ln.*input.k:22"     || { echo "FAIL: ! first arm not reported on line 22";    exit 1; }
echo "$QAT" | grep -q "std.io:print.ln.*input.k:23"     || { echo "FAIL: | none arm not reported on line 23";     exit 1; }

echo "=== flow hash reports the flow head's own line ==="
FAT=$(koruc "$KORU_INPUT" at "${QHASH:0:6}" 2>&1)
echo "$FAT"
echo "$FAT" | grep -q "^  flow  std.store:insert.*input.k:17" || { echo "FAIL: flow head not reported on line 17"; exit 1; }

echo "=== --ast-json continuation locations are user lines ==="
koruc "$KORU_INPUT" --ast-json 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
found = []
def walk(o):
    if isinstance(o, dict):
        if o.get("type") == "flow":
            for c in o.get("continuations", []):
                found.append((c.get("branch"), c.get("location", {}).get("line")))
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(d["items"])
assert ("row", 18) in found, "arm continuation not on its own line: %r" % found
' || { echo "FAIL: ast-json continuation line not user coords"; exit 1; }

echo "=== PASS: at reports site lines ==="

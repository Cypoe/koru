#!/bin/bash
# Structural pin: the input file contributes three print.blk flows to
# program.ast.json. Two means the empty block swallowed the following
# declaration — the defect this test exists to refuse.
set -e
COUNT=$(python3 -c "
import json
ast = json.load(open('program.ast.json'))
n = 0
def walk(o):
    global n
    if isinstance(o, dict):
        loc = o.get('location') or {}
        inv = (o.get('node') or {}).get('invocation') if isinstance(o.get('node'), dict) else None
        if inv and '$KORU_INPUT' in str(loc.get('file', '')):
            p = inv.get('path', {})
            if p.get('segments') == ['print', 'blk']:
                n += 1
        for v in o.values():
            walk(v)
    elif isinstance(o, list):
        for v in o:
            walk(v)
walk(ast)
print(n)
")
[ "$COUNT" = "3" ] || { echo "FAIL: expected 3 print.blk flows from input, got $COUNT — empty source block ate a declaration"; exit 1; }

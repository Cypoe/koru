#!/bin/bash
# The suite builds without --release=fast, so the banner must say Debug —
# this pins BOTH halves: the mode is named, and the default stayed Debug.
set -u
if [ ! -f backend.out ]; then
    echo "FAIL: no backend.out"
    exit 1
fi
if ! grep -q 'Compiled to output (Debug)' backend.out; then
    echo "FAIL: success line does not name the build mode"
    cat backend.out
    exit 1
fi
echo "PASS: success line names the build mode (Debug default intact)"
exit 0

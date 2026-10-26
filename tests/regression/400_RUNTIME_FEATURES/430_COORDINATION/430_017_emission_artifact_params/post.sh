#!/bin/bash
# dir: must relocate the artifact — stage/output_emitted.zig exists and
# no cwd copy was written. Both directions pinned: a write-artifact that
# ignored `dir` leaves the cwd copy; a host-build-zig that ignored `dir`
# would have failed the build already (stage/ held the only source).

if [ ! -f "stage/output_emitted.zig" ]; then
    echo "FAIL: dir:\"stage\" did not relocate the artifact — stage/output_emitted.zig missing"
    exit 1
fi
if [ -f "output_emitted.zig" ]; then
    echo "FAIL: dir:\"stage\" left a cwd copy — output_emitted.zig should only exist under stage/"
    exit 1
fi
exit 0

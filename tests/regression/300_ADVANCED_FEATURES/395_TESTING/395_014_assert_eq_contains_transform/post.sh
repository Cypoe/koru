#!/bin/bash
# The emitted test decls only execute under `zig test` — run them.

cd "$(dirname "$0")"

zig test output_emitted.zig 2>&1
exit $?

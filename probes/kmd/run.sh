#!/bin/sh
set -e
cd "$(dirname "$0")"
# .kmd compiles straight to the document — no lowering, no backend.
# demo.kmd is the input; output_emitted.md is the artifact.
../../zig-out/bin/koruc demo.kmd

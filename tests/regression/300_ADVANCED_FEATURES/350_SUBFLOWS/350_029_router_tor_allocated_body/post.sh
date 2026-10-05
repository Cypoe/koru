#!/bin/bash
# Pin: the mark rides the tor's allocated! return, not the producer's
# emission shape. A non-inline `|> render(): b -> { body: b }` arm must
# emit `body_allocated = true` on the Response record — the flag
# release-body reads. Without it the body frees nothing and the produced
# program's leak check fires at exit.
set -e
grep -q "body_allocated = true" output_emitted.zig || {
    echo "FAIL: Response record missing .body_allocated = true — allocated! return not propagated to the mark"
    exit 1
}

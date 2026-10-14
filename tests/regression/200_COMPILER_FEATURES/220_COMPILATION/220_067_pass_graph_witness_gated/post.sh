#!/bin/bash
# No enforce -> zero pass-graph arcs in the comptime channel.
if grep -q "pass-graph" backend.out backend.err 2>/dev/null; then
    echo "pass-graph witness lines emitted without enforce" >&2
    exit 1
fi

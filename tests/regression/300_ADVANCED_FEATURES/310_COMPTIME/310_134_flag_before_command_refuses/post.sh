#!/bin/bash
# The failure this pins: a flag before the command used to fall through to a
# normal build, ignoring the command entirely. Correct behavior is a nonzero
# refusal naming the command, while command-first order still runs it.
set -e

if koruc "$KORU_INPUT" --build=dev ordercmd > /tmp/koru_134_out 2>&1; then
    echo "FAIL: flag-first invocation did not refuse"
    cat /tmp/koru_134_out
    exit 1
fi
grep -q "'ordercmd' is a command" /tmp/koru_134_out || {
    echo "FAIL: refusal did not name the command"
    cat /tmp/koru_134_out
    exit 1
}

koruc "$KORU_INPUT" ordercmd --build=dev > /tmp/koru_134_ok 2>&1
grep -q "ordercmd ran" /tmp/koru_134_ok || {
    echo "FAIL: command-first invocation did not run the command"
    cat /tmp/koru_134_ok
    exit 1
}

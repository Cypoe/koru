#!/bin/bash
# The gated module is imported UNCONDITIONALLY, so its flag.declare must
# be visible to --help even though the override itself gated out. (With
# import-level gating this flag would be undiscoverable — the hole the
# item gate closes.)
set -e
HELP_OUTPUT=$(koruc input.kz --help 2>&1)
echo "$HELP_OUTPUT" | grep -q "my-flag" || {
    echo "FAIL: --my-flag missing from --help although its module is imported"
    exit 1
}
echo "PASS: gated module's flag.declare visible in --help"
# Gate exclusion verdicts are build diagnostics: they must never reach
# --help output, even though the help parse evaluates (and drops) the
# same gated items.
if echo "$HELP_OUTPUT" | grep -q "no gate entry true"; then
    echo "FAIL: gate exclusion verdict leaked into --help output"
    exit 1
fi
echo "PASS: --help carries no gate verdicts"

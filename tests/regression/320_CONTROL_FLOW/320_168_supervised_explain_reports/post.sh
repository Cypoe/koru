#!/bin/bash
# `koruc explain` gathers [explainer] reports: std/supervisor reports the
# supervised site — producer, declared vocabulary, generated step/fold,
# policy rows, the re-entry scope lift — then the `elaborated` section
# prints the transform's own output (the pass ran on a clone).
set -e

echo "=== koruc explain (text) ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/supervisor"                        || { echo "FAIL: supervisor report missing";   exit 1; }
echo "$TEXT" | grep -q "connect → dial"                          || { echo "FAIL: site section missing";        exit 1; }
echo "$TEXT" | grep -q "produces = dial(port)"                   || { echo "FAIL: producer missing";            exit 1; }
echo "$TEXT" | grep -q "declares = | ok | refused"               || { echo "FAIL: vocabulary missing";          exit 1; }
echo "$TEXT" | grep -q "all void; nothing rides them"            || { echo "FAIL: void honesty missing";        exit 1; }
echo "$TEXT" | grep -q "becomes = __sup_step_L"                  || { echo "FAIL: step name missing";           exit 1; }
echo "$TEXT" | grep -q "port (the attempt's input)"              || { echo "FAIL: scope lift missing";          exit 1; }
echo "$TEXT" | grep -q "the retries-spent counter"               || { echo "FAIL: counter row missing";         exit 1; }

echo "=== elaborated section prints the transform's output ==="
echo "$TEXT" | grep -q "elaborated — the transform's output"     || { echo "FAIL: elaborated section missing";  exit 1; }
echo "$TEXT" | grep -q "__sup_step_L"                            || { echo "FAIL: step decl not printed";       exit 1; }
echo "$TEXT" | grep -q "| __more s |> @__sup_L"                  || { echo "FAIL: fold arm not printed";        exit 1; }
echo "$TEXT" | grep -q "when t < 5 => __more"                    || { echo "FAIL: retry guard not printed";     exit 1; }
echo "$TEXT" | grep -q "#__sup_L"                                || { echo "FAIL: label fold not printed";      exit 1; }

echo "=== witness hash resolves via koruc at ==="
echo "$TEXT" | grep -qE "site = \| refused \|> supervised \[[0-9a-z]+\]" || { echo "FAIL: site witness missing"; exit 1; }
HASH=$(echo "$TEXT" | grep -oE "supervised \[[0-9a-z]+\]" | grep -oE "\[[0-9a-z]+\]" | tr -d '[]')
AT=$(koruc "$KORU_INPUT" at "$HASH" 2>&1)
echo "$AT"
echo "$AT" | grep -q "input.k"                                   || { echo "FAIL: at lost the file";           exit 1; }

echo "=== koruc explain json (typed catalog) ==="
JSON=$(koruc "$KORU_INPUT" explain json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"std/supervisor"'                        || { echo "FAIL: report not in catalog";      exit 1; }
echo "$JSON" | grep -q '"becomes"'                               || { echo "FAIL: step row not in catalog";    exit 1; }

echo "=== PASS: explain reports the supervised elaboration ==="

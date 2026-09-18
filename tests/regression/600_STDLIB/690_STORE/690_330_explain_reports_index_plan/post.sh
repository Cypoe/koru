#!/bin/bash
# `koruc explain` on an indexed store: the `index` row names the declared
# column and carries the declaration site's witness hash, and each query
# site reports the plan the transform's fold routes it to — index lookup,
# sweep, or early-exit sweep — with refusals in the transform's own words.
set -e

echo "=== koruc explain (text) ==="
TEXT=$(koruc "$KORU_INPUT" explain 2>&1)
echo "$TEXT"
echo "$TEXT" | grep -q "📖 std/store"                                    || { echo "FAIL: store report missing";        exit 1; }
echo "$TEXT" | grep -qE "index = key \[[0-9a-z]+\]"                      || { echo "FAIL: index row missing";           exit 1; }
echo "$TEXT" | grep -qE "inserts = 3 \[[0-9a-z]+\] \[[0-9a-z]+\] \[[0-9a-z]+\]" || { echo "FAIL: insert count/witnesses missing"; exit 1; }
echo "$TEXT" | grep -qE "queries = 4( \[[0-9a-z]+\]){4}"                   || { echo "FAIL: query count/witnesses missing"; exit 1; }
test "$(echo "$TEXT" | grep -c "index lookup on key")" = "2"             || { echo "FAIL: nested routed plan missing";  exit 1; }
echo "$TEXT" | grep -q "index lookup on key"                             || { echo "FAIL: routed plan missing";         exit 1; }
echo "$TEXT" | grep -q "! query q — sweep"                               || { echo "FAIL: sweep plan missing";          exit 1; }
echo "$TEXT" | grep -q "sweep, stops at first match"                     || { echo "FAIL: scan plan missing";           exit 1; }
echo "$TEXT" | grep -q "input:tree"                                      || { echo "FAIL: tree section missing";        exit 1; }
echo "$TEXT" | grep -qE "queries = 2 \[[0-9a-z]+\] \[[0-9a-z]+\]"          || { echo "FAIL: nested tree query unwitnessed"; exit 1; }
test "$(echo "$TEXT" | grep -c "! first n — sweep, stops at first match")" = "2" || { echo "FAIL: tree plan missing";           exit 1; }
! echo "$TEXT" | grep -q "refused:"                                      || { echo "FAIL: a plan row refused";          exit 1; }

echo "=== second insert witness resolves to the chained insert ==="
IHASH=$(echo "$TEXT" | grep -oE "inserts = 3 \[[0-9a-z]+\] \[[0-9a-z]+\]" | grep -oE "\[[0-9a-z]+\]" | tail -1 | tr -d '[]')
IAT=$(koruc "$KORU_INPUT" at "$IHASH" 2>&1)
echo "$IAT"
echo "$IAT" | grep -q "std.store:insert"                                  || { echo "FAIL: at missed the chained insert"; exit 1; }

echo "=== deep-nested query witness resolves and drifts gracefully ==="
QHASH=$(echo "$TEXT" | grep -oE "query\[0\] = ! first p — index lookup on key \[[0-9a-z]+\]" | grep -oE "\[[0-9a-z]+\]" | tail -1 | tr -d '[]')
QAT=$(koruc "$KORU_INPUT" at "$QHASH" 2>&1)
echo "$QAT"
echo "$QAT" | grep -q "std.store:query"                                  || { echo "FAIL: at missed the nested query";  exit 1; }
koruc "$KORU_INPUT" at "${QHASH}aa" 2>&1 | grep -q "tail drifted"        || { echo "FAIL: deep descent did not drift";  exit 1; }

echo "=== index witness resolves to the declaration site ==="
HASH=$(echo "$TEXT" | grep -oE "index = key \[[0-9a-z]+\]" | grep -oE "\[[0-9a-z]+\]" | tr -d '[]')
AT=$(koruc "$KORU_INPUT" at "$HASH" 2>&1)
echo "$AT"
echo "$AT" | grep -q "std.indexes:store"                                 || { echo "FAIL: at missed the index decl";    exit 1; }
echo "$AT" | grep -q "input.k"                                           || { echo "FAIL: at lost the file";            exit 1; }

echo "=== koruc explain json (typed) ==="
JSON=$(koruc "$KORU_INPUT" explain json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"index":"key"'                                   || { echo "FAIL: index not in json";           exit 1; }

echo "=== PASS: explain reports the index plan ==="

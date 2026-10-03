#!/bin/bash
# Pins the world file as an artifact: session a's define must have written
# verbatim definition source to world/greet.k — the genome is a file that
# reads like a program, not a serialized table. Then removes it so the pin
# leaves no residue in the tree.
set -u
cd "$(dirname "$0")"
fail() { echo "FAIL: $1"; exit 1; }

[ -f world/greet.k ] || fail "world/greet.k was not written by session a's define"
grep -qx 'tor greet { text: string }' world/greet.k || fail "world/greet.k is not verbatim definition source"
grep -qx 'greet = echo(text)' world/greet.k || fail "world/greet.k body is not verbatim"

rm -rf world

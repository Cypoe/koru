#!/usr/bin/env bash
# koru_line_baselines.sh — print `path<TAB>lines` for every tracked Koru file
# under koru_std/ and examples/. The rows are the growth wall's pins
# (git_wall.sh): a staged file may not grow past its pinned size — split it
# with `~part` instead. Regenerate and commit the new baseline as part of any
# split; the wall refuses a regeneration that widens a row.
set -o pipefail
cd "$(dirname "$0")/.."
git ls-files | grep -E '^(koru_std|examples)/.*\.k(z|js|c|gpu)?$' | sort | while read -r f; do
    printf '%s\t%s\n' "$f" "$(wc -l < "$f" | tr -d ' ')"
done

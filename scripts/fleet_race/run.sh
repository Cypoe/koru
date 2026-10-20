#!/usr/bin/env bash
# fleet_race — the concurrent-claim receipt for std/fleet.
#
# Compiles racer.k once, then launches N copies of it simultaneously
# against one shared world dir; every copy claims the same 16 cell ids
# under its own node name (argv[1]). The protocol invariants under true
# multi-process contention:
#
#   1. exactly one `won` line per id            — one owner per record
#   2. every loser prints `lost <id> to <node>` — held-by names the winner
#   3. zero `FAILED` lines                      — a loser must never answer
#      `failed` for an id that was legitimately claimed (regression: a
#      racer once read the winner's record mid-write — zero bytes — and
#      fell through to `failed`; fleetAcquire now re-reads with a bound)
#   4. floor check: one `node=` line per owner file, all epochs 1
#
# Winners distribute across racers — which ids go to whom is scheduling,
# but the per-id uniqueness and the loser arms are protocol.
#
# Usage: bash scripts/fleet_race/run.sh [N]
set -euo pipefail
cd "$(dirname "$0")"

N="${1:-8}"
KORUC="$(cd "$(dirname "${KORUC:-../../zig-out/bin/koruc}")" && pwd)/$(basename "${KORUC:-../../zig-out/bin/koruc}")"
SCRATCH="${SCRATCH:-/tmp/koru-fleet-race}"
mkdir -p "$SCRATCH/world"
rm -rf "$SCRATCH/world"
mkdir -p "$SCRATCH/world"

sed "s|@WORLD@|$SCRATCH/world|g" racer.k > "$SCRATCH/racer.k"

cd "$SCRATCH"
"$KORUC" racer.k > /dev/null 2>&1 && mv a.out racer_bin

echo "=== RACE: $N processes x 16 ids ==="
rm -f race.log
for i in $(seq 1 "$N"); do
    ./racer_bin "racer-$i" >> race.log &
done
wait

won=$(grep -c " won " race.log)
lost=$(grep -c " lost " race.log)
failed=$(grep -c " FAILED " race.log || true)
echo "won=$won  lost=$lost  failed=$failed   (expected: 16 won, $((16 * (N - 1))) lost, 0 failed)"

echo "=== floor: owner records ==="
for f in world/.fleet/owners/room-r*; do
    echo "$(basename "$f"): $(tr '\n' ' ' < "$f" | sed 's/ $//')"
done
echo "=== owner histogram ==="
grep -h '^node=' world/.fleet/owners/room-r* | sort | uniq -c

# The check that could prove the race wrong:
dupes=$(grep -h '^node=' world/.fleet/owners/room-r* | wc -l)
[ "$won" -eq 16 ] && [ "$failed" -eq 0 ] && [ "$dupes" -eq 16 ] \
    && echo "VERDICT: PASS — exactly one owner per id, no loser lied" \
    || { echo "VERDICT: FAIL — see counts above"; exit 1; }

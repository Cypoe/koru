#!/usr/bin/env bash
# seize_race — the concurrent-takeover receipt for std/fleet.
#
# Seeds 8 ids under 'deadnode' at epoch 1, then launches N processes
# racing `std/fleet:seize` on all of them. seize is serialized takeover,
# not exclusive claim — every racer that holds the lock legitimately
# wins at its own bumped epoch. The protocol assertions:
#
#   1. per id, seized epochs are unique AND contiguous 2..k+1  — the lock
#      serialized every bump; a skipped or duplicated epoch means the
#      bump raced the write
#   2. the final record names the max-epoch seizer             — last
#      serialized takeover is the record
#   3. zero 'LIED free' / 'FAILED'                             — records
#      exist the whole race; free would be a lie, failed means I/O broke
#   4. 'contended' is legal and counted                        — the lock
#      answering honestly to a simultaneous collider
#
# Usage: bash scripts/fleet_race/seize_race.sh [N]
set -euo pipefail
cd "$(dirname "$0")"

N="${1:-8}"
KORUC="$(cd "$(dirname "${KORUC:-../../zig-out/bin/koruc}")" && pwd)/$(basename "${KORUC:-../../zig-out/bin/koruc}")"
SCRATCH="${SCRATCH:-/tmp/koru-fleet-seize}"
mkdir -p "$SCRATCH/world"
rm -rf "$SCRATCH/world"
mkdir -p "$SCRATCH/world"

sed "s|@WORLD@|$SCRATCH/world|g" seed.k > "$SCRATCH/seed.k"
sed "s|@WORLD@|$SCRATCH/world|g" seizer.k > "$SCRATCH/seizer.k"

cd "$SCRATCH"
"$KORUC" seed.k > /dev/null 2>&1 && mv a.out seed_bin
"$KORUC" seizer.k > /dev/null 2>&1 && mv a.out seizer_bin

./seed_bin deadnode

echo "=== SEIZE RACE: $N processes x 8 ids ==="
rm -f race.log
for i in $(seq 1 "$N"); do
    ./seizer_bin "racer-$i" >> race.log &
done
wait

seized=$(grep -c " seized " race.log)
contended=$(grep -c " contended " race.log)
lied=$(grep -c " LIED " race.log || true)
failed=$(grep -c " FAILED " race.log || true)
echo "seized=$seized  contended=$contended  lied=$lied  failed=$failed"

verdict=PASS
for id in room-s01 room-s02 room-s03 room-s04 room-s05 room-s06 room-s07 room-s08; do
    epochs=$(grep " seized $id " race.log | sed 's/.*@//' | sort -n)
    count=$(echo "$epochs" | grep -c . || true)
    # uniqueness + contiguity: sorted epochs must be exactly 2..count+1
    expected=$(seq 2 $((count + 1)) 2>/dev/null || true)
    if [ "$epochs" != "$expected" ]; then
        echo "  $id: EPOCH SET WRONG — got: $(echo $epochs | tr '\n' ' ')"
        verdict=FAIL
    fi
    # the record must name whoever seized the max epoch
    maxe=$((count + 1))
    winner=$(grep " seized $id @$maxe" race.log | cut -d' ' -f1)
    recnode=$(grep '^node=' "world/.fleet/owners/$id" | cut -d= -f2)
    recep=$(grep '^epoch=' "world/.fleet/owners/$id" | cut -d= -f2)
    if [ "$recnode" != "$winner" ] || [ "$recep" != "$maxe" ]; then
        echo "  $id: record says $recnode@$recep but max seizor was $winner@$maxe"
        verdict=FAIL
    else
        echo "  $id: $count serialized takeovers, final = $winner@$maxe"
    fi
done

[ "$lied" -eq 0 ] && [ "$failed" -eq 0 ] && [ "$verdict" = PASS ] \
    && echo "VERDICT: PASS — takeovers serialized, records consistent" \
    || { echo "VERDICT: FAIL"; exit 1; }

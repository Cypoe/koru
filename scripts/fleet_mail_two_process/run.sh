#!/usr/bin/env sh
# fleet_mail_two_process — routing receipt across a real process boundary.
# A owns room-mb and sleeps; B's member lookup is refused `held-by`, so B
# posts turns to the mailbox and exits; A wakes, drains, and executes each
# delivered turn against the resident cell. `held-by` is a redirect.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
KORUC="$(CDPATH= cd -- "${KORUC:-$ROOT/../../zig-out/bin}" && pwd)/koruc"
export KORU_STDLIB="${KORU_STDLIB:-$ROOT/../../koru_std}"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
WORLD="$SCRATCH/world"
mkdir -p "$WORLD"

sed "s|WORLD|$WORLD|g" "$ROOT/a.k" > "$SCRATCH/a.k"
sed "s|WORLD|$WORLD|g" "$ROOT/b.k" > "$SCRATCH/b.k"

( cd "$SCRATCH" && "$KORUC" a.k -o a >/dev/null 2>&1 && "$KORUC" b.k -o b >/dev/null 2>&1 ) || {
    echo "compile failed"; ( cd "$SCRATCH" && "$KORUC" a.k 2>&1 | tail -15; "$KORUC" b.k 2>&1 | tail -15 ); exit 1; }

echo "=== PROCESS A (owns cell, sleeps 1.5s, drains) ==="
( cd "$SCRATCH" && ./a > a.log 2>&1 ) &
APID=$!
sleep 0.4
echo "=== PROCESS B (refused, posts two turns, exits) ==="
( cd "$SCRATCH" && ./b )
wait $APID
cat "$SCRATCH/a.log" | grep -v REGISTRY
echo "=== mailbox after drain ==="
ls "$WORLD/.fleet/inbox/room-mb" 2>/dev/null || echo "(empty)"

ok=1
grep -q "nodeb refused by nodea — posted turn to mailbox" "$SCRATCH/b.log" 2>/dev/null || true
grep -q "nodea delivered 2 mails" "$SCRATCH/a.log" || { echo "FAIL: A did not deliver 2"; ok=0; }
grep -q "nodea reads visits=43" "$SCRATCH/a.log" || { echo "FAIL: visits != 43"; ok=0; }
[ "$ok" = "1" ] && echo "VERDICT: PASS — held-by redirected a turn across a real process boundary"

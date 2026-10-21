#!/usr/bin/env bash
# fleet_lease_two_process — the cross-process lease receipt.
#
# Process A leases room-42 (ttl 900ms), writes state, exits — the
# record survives with a deadline already running. A probe process at
# ~400ms is refused `held-by nodea` while the lease is live. Process B
# starts after the deadline passes (~1.4s) and its member lookup takes
# the expired lease through the same serialized takeover seize runs —
# no operator, the clock is the failure detector. B reads A's durable
# state (visits=41) and commits under the new epoch (42).
#
# Self-verifying: exits nonzero if any phase deviates.
#
# Usage: bash scripts/fleet_lease_two_process/run.sh
set -euo pipefail
cd "$(dirname "$0")"

KORUC="$(cd "$(dirname "${KORUC:-../../zig-out/bin/koruc}")" && pwd)/$(basename "${KORUC:-../../zig-out/bin/koruc}")"
SCRATCH="${SCRATCH:-/tmp/koru-fleet-lease-2proc}"
mkdir -p "$SCRATCH/world"
rm -rf "$SCRATCH/world"
mkdir -p "$SCRATCH/world"

# The programs bake the world path; keep it in sync if SCRATCH changes.
for p in a probe b; do
    sed "s|/tmp/koru-fleet-lease-2proc/world|$SCRATCH/world|g" "$p.k" > "$SCRATCH/$p.k"
done

cd "$SCRATCH"
for p in a probe b; do
    "$KORUC" "$p.k" > "$p.compile.log" 2>&1 || { cat "$p.compile.log"; exit 1; }
    mv a.out "${p}_bin"
done

echo "=== PROCESS A (leases, writes, exits) ==="
./a_bin | tee a.out.log
echo "--- owner record after A exits ---"
cat world/.fleet/owners/room-42

grep -q "nodea spawned room-42" a.out.log
grep -q "nodea committed visits=41" a.out.log
grep -q "node=nodea" world/.fleet/owners/room-42
grep -q "epoch=1" world/.fleet/owners/room-42
grep -qE "until=[1-9]" world/.fleet/owners/room-42 \
    || { echo "FAIL: lease deadline missing on record"; exit 1; }

echo "=== PROBE at ~400ms (lease live: must be held-by) ==="
sleep 0.4
./probe_bin | tee probe.out.log
grep -q "probe refused: held by nodea" probe.out.log \
    || { echo "FAIL: live lease did not refuse the probe"; exit 1; }

echo "=== PROCESS B at ~1.5s (lease lapsed: lookup takes it) ==="
sleep 1.1
./b_bin | tee b.out.log
grep -q "nodeb activated lapsed lease, reads visits=41" b.out.log \
    || { echo "FAIL: B did not activate A's durable state"; exit 1; }
grep -q "nodeb committed visits=42" b.out.log \
    || { echo "FAIL: B's write did not land"; exit 1; }

echo "--- owner record after B ---"
cat world/.fleet/owners/room-42
grep -q "node=nodeb" world/.fleet/owners/room-42 \
    || { echo "FAIL: record does not name nodeb"; exit 1; }
grep -q "epoch=2" world/.fleet/owners/room-42 \
    || { echo "FAIL: takeover did not bump the epoch"; exit 1; }

echo "VERDICT: PASS — lease outlived the process, refused while live, lapsed to a new owner by the clock"

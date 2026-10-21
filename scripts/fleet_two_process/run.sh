#!/usr/bin/env bash
# fleet_two_process — the cross-process receipt for std/fleet.
#
# Compiles nodea.k and nodeb.k into separate binaries and runs them
# sequentially against one shared world dir. Process A claims room-42,
# writes state, and exits — the ownership record must outlive it.
# Process B, a fresh OS process, reads the record (owned-by nodea),
# is refused at member lookup (held-by), seizes at epoch 2, activates
# the durable state (visits=41), and commits under its own epoch (42).
#
# The regression harness runs one program per test dir; this protocol
# exists for the boundary between two real processes, so the receipt
# lives here as a driver until the suite grows a multi-binary shape.
#
# Usage: bash scripts/fleet_two_process/run.sh
set -euo pipefail
cd "$(dirname "$0")"

KORUC="$(cd "$(dirname "${KORUC:-../../zig-out/bin/koruc}")" && pwd)/$(basename "${KORUC:-../../zig-out/bin/koruc}")"
SCRATCH="${SCRATCH:-/tmp/koru-fleet-2proc}"
mkdir -p "$SCRATCH/world"
rm -rf "$SCRATCH/world"
mkdir -p "$SCRATCH/world"

# The programs bake the world path; keep it in sync if SCRATCH changes.
sed "s|/tmp/koru-fleet-2proc/world|$SCRATCH/world|g" nodea.k > "$SCRATCH/nodea.k"
sed "s|/tmp/koru-fleet-2proc/world|$SCRATCH/world|g" nodeb.k > "$SCRATCH/nodeb.k"

cd "$SCRATCH"
"$KORUC" nodea.k > /dev/null 2>&1 && mv a.out nodea_bin
"$KORUC" nodeb.k > /dev/null 2>&1 && mv a.out nodeb_bin

echo "=== PROCESS A (claims, writes, exits) ==="
./nodea_bin
echo "=== floor after A exits ==="
find world -type f | sort
echo "--- owner record ---"
cat world/.fleet/owners/room-42
echo "=== PROCESS B (probe, held-by, seize, activate, write) ==="
./nodeb_bin

#!/usr/bin/env sh
# 013_cell_node — Orleans counter-grain workload: per turn = method call
# (interpreter dispatch) + durable state write (capture commit → state.kv).
#
# Arms:
#   koru resident   — worldless node: turns with no materializer
#   koru durable    — world-mounted node: every commit writes state.kv
#   koru durable+sync — same commits, fsync'd per turn (celld's ack level)
#   koru activation — evict + member-lookup cycles (hibernate → re-materialize)
#   zig baseline    — same semantics, no interpreter: the speed of light
#
# Correctness gate: each grain must show hits == TURNS — a stage that never
# ran shows up as a wrong checksum, not a fast number.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
KORUC="${KORUC:-$ROOT/../../../zig-out/bin/koruc}"
export KORU_STDLIB="${KORU_STDLIB:-$ROOT/../../../koru_std}"
TURNS=60

if [ ! -x "$KORUC" ]; then
    echo "koruc not built at $KORUC — run 'zig build' first" >&2
    exit 1
fi

rm -rf /tmp/koru-bench-cells /tmp/koru-bench-baseline
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "== compile task.kz"
( cd "$work" && cp "$ROOT/task.kz" . && "$KORUC" task.kz -o task_bin >/dev/null 2>&1 ) || \
( cd "$work" && "$KORUC" task.kz 2>&1 | tail -20; exit 1 )
[ -x "$work/task_bin" ] || { echo "no task_bin produced"; exit 1; }

echo "== run koru arms"
out="$(cd "$work" && ./task_bin)"
printf '%s\n' "$out" | grep -E 'resident:|durable|activation:|hits=|drained'

echo "== correctness gate"
df_hits="$(printf '%s\n' "$out" | sed -n 's/^df hits=\([0-9]*\).*/\1/p')"
rf_hits="$(printf '%s\n' "$out" | sed -n 's/^rf hits=\([0-9]*\).*/\1/p')"
ds_hits="$(printf '%s\n' "$out" | sed -n 's/^ds hits=\([0-9]*\).*/\1/p')"
[ "$df_hits" = "$TURNS" ] || { echo "df hits=$df_hits, want $TURNS"; exit 1; }
[ "$rf_hits" = "$TURNS" ] || { echo "rf hits=$rf_hits, want $TURNS"; exit 1; }
[ "$ds_hits" = "$TURNS" ] || { echo "ds hits=$ds_hits, want $TURNS"; exit 1; }
echo "checksum ok: df=$df_hits rf=$rf_hits ds=$ds_hits (want $TURNS each)"

echo "== zig baseline"
zig run -OReleaseFast "$ROOT/baseline.zig"

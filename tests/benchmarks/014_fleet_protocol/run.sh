#!/usr/bin/env sh
# 014_fleet_protocol — the fleet verbs' per-op floor cost.
#
# Arms:
#   owner         — the routing probe: one record read
#   claim+release — the createNew CAS round trip + record delete
#   renew         — locked lease refresh
#   seize         — serialized takeover under the lock dir
#   zig baseline  — identical syscall sequences, no runtime — speed of light
#
# Correctness gate: epochs/cycle must equal TURNS (each claim bumps the
# persistent counter) and epochs/seizable must equal TURNS+1 (claim + TURNS
# takeovers). A verb that silently fell into a cheap arm shows up as a wrong
# counter, not a suspiciously fast number.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
KORUC="${KORUC:-$ROOT/../../../zig-out/bin/koruc}"
export KORU_STDLIB="${KORU_STDLIB:-$ROOT/../../../koru_std}"
TURNS=60
WORLD=/tmp/koru-bench-fleet

if [ ! -x "$KORUC" ]; then
    echo "koruc not built at $KORUC — run 'zig build' first" >&2
    exit 1
fi

rm -rf "$WORLD" /tmp/koru-bench-fleet-baseline
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "== compile task.kz"
( cd "$work" && cp "$ROOT/task.kz" . && "$KORUC" task.kz -o task_bin >/dev/null 2>&1 ) || \
( cd "$work" && "$KORUC" task.kz 2>&1 | tail -20; exit 1 )
[ -x "$work/task_bin" ] || { echo "no task_bin produced"; exit 1; }

echo "== run koru arms"
out="$(cd "$work" && ./task_bin)"
printf '%s\n' "$out" | grep -E 'owner:|claim\+release:|renew:|seize:|held|free|failed|contended|not-owner'

echo "== correctness gate"
bad="$(printf '%s\n' "$out" | grep -cE 'held by|free|failed|contended|not-owner' || true)"
[ "$bad" = "0" ] || { echo "protocol arms degraded: $bad stray outcome lines"; exit 1; }
cycle_epoch="$(cat "$WORLD/.fleet/epochs/cycle" 2>/dev/null | tr -d '[:space:]')"
seize_epoch="$(cat "$WORLD/.fleet/epochs/seizable" 2>/dev/null | tr -d '[:space:]')"
[ "$cycle_epoch" = "$TURNS" ] || { echo "cycle epoch=$cycle_epoch, want $TURNS"; exit 1; }
want_seize=$((TURNS + 1))
[ "$seize_epoch" = "$want_seize" ] || { echo "seizable epoch=$seize_epoch, want $want_seize"; exit 1; }
echo "counters ok: cycle=$cycle_epoch (want $TURNS) seizable=$seize_epoch (want $want_seize)"

echo "== zig baseline"
zig run -OReleaseFast "$ROOT/baseline.zig"

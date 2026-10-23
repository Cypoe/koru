#!/usr/bin/env sh
# 015_fleet_mail — the routed turn: held-by → mailbox post → owner drains and
# executes. Arms:
#   koru send      — post TURNS turn files (tmp+rename into .fleet/inbox)
#   koru deliver   — drain: per mail, execute the turn + durable commit + delete
#   koru pipelined — 8 host producers claim-post TURNS mails into a capacity-16
#                    channel ring; the pump drains them as custody-minted turns
#                    (+1 warmup mail through the Koru send path seeds transit)
#   zig baseline   — the same file lifecycle, no interpreter or turn execution
#
# Correctness gate: grain hits must equal 2*TURNS+1 (every routed turn
# committed exactly once, both tiers) and file drain must report TURNS
# delivered.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
KORUC="${KORUC:-$ROOT/../../../zig-out/bin/koruc}"
export KORU_STDLIB="${KORU_STDLIB:-$ROOT/../../../koru_std}"
TURNS=60

if [ ! -x "$KORUC" ]; then
    echo "koruc not built at $KORUC — run 'zig build' first" >&2
    exit 1
fi

rm -rf /tmp/koru-bench-mail /tmp/koru-bench-mail-baseline
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "== compile task.kz"
( cd "$work" && cp "$ROOT/task.kz" . && "$KORUC" task.kz -o task_bin >/dev/null 2>&1 ) || \
( cd "$work" && "$KORUC" task.kz 2>&1 | tail -20; exit 1 )
[ -x "$work/task_bin" ] || { echo "no task_bin produced"; exit 1; }

echo "== run koru arms"
out="$(cd "$work" && ./task_bin)"
printf '%s\n' "$out" | grep -E 'send:|deliver|pipelined|hits=|drained|held by|BUG'

echo "== correctness gate"
mb_hits="$(printf '%s\n' "$out" | sed -n 's/^mb hits=\([0-9]*\).*/\1/p')"
delivered="$(printf '%s\n' "$out" | sed -n 's/^delivered \([0-9]*\) mails.*/\1/p')"
want_hits=$((2 * TURNS + 1))
[ "$mb_hits" = "$want_hits" ] || { echo "mb hits=$mb_hits, want $want_hits"; exit 1; }
[ "$delivered" = "$TURNS" ] || { echo "delivered=$delivered, want $TURNS"; exit 1; }
echo "checksum ok: mb=$mb_hits delivered=$delivered (want $want_hits / $TURNS)"

echo "== zig baseline"
zig run -OReleaseFast "$ROOT/baseline.zig"

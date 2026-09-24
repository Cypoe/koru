#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OUT="$ROOT/results.jsonl"
ZIG_BIN="$ROOT/zig_flat/zig_flat"
KORUC="$ROOT/../../../zig-out/bin/koruc"
KORU_DIR="$ROOT/koru_price"
REPS="${REPS:-7}"

: > "$OUT"

zig build-exe "$ROOT/zig_flat/src/main.zig" -O ReleaseFast -femit-bin="$ZIG_BIN"

SCENARIOS="read_row capture_for read_handle write_row write_handle write_sink event_call insert insert_idx drain routed guarded watch grid"

if [ -x "$KORUC" ]; then
  # --release=fast is load-bearing: koruc defaults to Debug, and a Debug
  # binary timed against -O ReleaseFast anchors measures the safety checks,
  # not the codegen. Refuse to time anything not reporting ReleaseFast.
  build_log="$(cd "$KORU_DIR" && "$KORUC" build --release=fast main.k 2>&1)" \
    || { printf '%s\n' "$build_log" >&2; exit 1; }
  printf '%s\n' "$build_log" | grep -q '(ReleaseFast)' \
    || { printf '%s\n' "$build_log" >&2; echo "koruc did not report ReleaseFast — refusing to time" >&2; exit 1; }
else
  echo "koruc not built (zig build); skipped Koru entry" >&2
  exit 1
fi

# Interleaved reps: thermal/scheduling drift lands in the median, not in
# one impl's ordering slot.
for rep in $(seq 1 "$REPS"); do
  for scenario in $SCENARIOS; do
    "$ZIG_BIN" --scenario "$scenario" --entities 100000 --frames 100 >> "$OUT"
    "$KORU_DIR/a.out" --scenario "$scenario" --entities 100000 --frames 100 >> "$OUT"
  done
done

cat "$OUT"

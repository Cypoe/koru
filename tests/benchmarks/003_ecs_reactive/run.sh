#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OUT="$ROOT/results.jsonl"
ZIG_BIN="$ROOT/zig_striped/zig_striped"
KORUC="$ROOT/../../../zig-out/bin/koruc"
KORU_DIR="$ROOT/koru_store"

: > "$OUT"

zig build-exe "$ROOT/zig_striped/src/main.zig" -O ReleaseFast -femit-bin="$ZIG_BIN"

SCENARIOS="spawn spawn_batch despawn add_remove query_get dense sparse schedule_empty fanout combat_world bevy_strength_world boids"

for scenario in $SCENARIOS; do
  frames=100
  if [ "$scenario" = "schedule_empty" ]; then
    frames=100000
  fi
  "$ZIG_BIN" --scenario "$scenario" --entities 100000 --frames "$frames" --observers 25 >> "$OUT"
done

if command -v cargo >/dev/null 2>&1; then
  for scenario in $SCENARIOS; do
    frames=100
    if [ "$scenario" = "schedule_empty" ]; then
      frames=100000
    fi
    cargo run --release --quiet --manifest-path "$ROOT/rust_bevy/Cargo.toml" -- \
      --scenario "$scenario" --entities 100000 --frames "$frames" --observers 25 >> "$OUT"
  done
else
  echo "cargo not found; skipped Bevy baseline" >&2
fi

# The Koru entry emits nothing for a scenario it has not ported yet — it
# refuses on stderr and exits 0 — so an absent line in results.jsonl means
# "not implemented", never "ran and produced nothing".
if [ -x "$KORUC" ]; then
  # --release=fast is load-bearing: koruc defaults to Debug, and a Debug
  # binary timed against -O ReleaseFast anchors measures the safety checks,
  # not the codegen. The build line names its mode — refuse to time
  # anything that does not report ReleaseFast.
  # --compile-mem-mb: this port's emit pass peaks past the 4 GB default
  # (KORU174). The budget is the sanctioned knob — raise it here, and treat
  # the peak itself as a compile-time performance finding.
  build_log="$(cd "$KORU_DIR" && "$KORUC" build --release=fast --compile-mem-mb=8192 main.k 2>&1)" \
    || { printf '%s\n' "$build_log" >&2; exit 1; }
  printf '%s\n' "$build_log" | grep -q '(ReleaseFast)' \
    || { printf '%s\n' "$build_log" >&2; echo "koruc did not report ReleaseFast — refusing to time" >&2; exit 1; }
  for scenario in $SCENARIOS; do
    frames=100
    if [ "$scenario" = "schedule_empty" ]; then
      frames=100000
    fi
    "$KORU_DIR/a.out" --scenario "$scenario" --entities 100000 --frames "$frames" --observers 25 >> "$OUT"
  done
else
  echo "koruc not built (zig build); skipped Koru entry" >&2
fi

cat "$OUT"

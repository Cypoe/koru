#!/usr/bin/env sh
# The X post's task — Where(score >= threshold).Select($"{ip} [{level}]")
# .ToList() — raced on .NET itself, plus the same task.k compiled native.
#
# The generated arms are real emitted artifacts: task.k is compiled
#   --lang=cs  -> output_emitted.cs, built INTO the benchmark assembly
#   (zig)      -> a.out ReleaseFast, timed as a whole process
# and invoked through the generated API. Comparator set and the verbatim
# ThreatScanner are declared in Program.cs before any measuring.
#
# Correctness control: every .NET arm must produce identical
# (count, chars); the zig binary's printed hits/chars must match too —
# a stage that never ran shows up as a wrong checksum.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
KORUC="${KORUC:-$ROOT/../../../zig-out/bin/koruc}"
export KORU_STDLIB="${KORU_STDLIB:-$ROOT/../../../koru_std}"

if [ ! -x "$KORUC" ]; then
    echo "koruc not built at $KORUC — run 'zig build' first" >&2
    exit 1
fi
if ! command -v dotnet >/dev/null 2>&1; then
    echo "dotnet not found; the .NET arms cannot run" >&2
    exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp "$ROOT/task.k" "$ROOT/task.kcs" "$ROOT/task.kz" "$work/"

# --- C# arm: emit + build into the benchmark assembly -----------------
( cd "$work" && "$KORUC" task.k --lang=cs >/dev/null 2>&1 )
[ -f "$work/output_emitted.cs" ] || { echo "no output_emitted.cs produced" >&2; exit 1; }

mkdir -p "$work/proj"
cp "$ROOT/Program.cs" "$ROOT/bench.csproj" "$work/output_emitted.cs" "$work/proj/"

echo
( cd "$work/proj" && dotnet build -c Release -o out >/dev/null )
"$work/proj/out/threat_scanner"

# --- Zig arm: same task.k, ReleaseFast, whole-process timing ----------
# The binary's printed hits/chars are the checksum; wall clock is the
# honest (slightly conservative — includes startup) measurement.
( cd "$work" && "$KORUC" build --release=fast task.k >/dev/null 2>&1 )
[ -x "$work/a.out" ] || { echo "no zig binary produced" >&2; exit 1; }

best=""
expect=""
i=0
while [ $i -lt 3 ]; do
    start=$(python3 -c 'import time; print(time.time_ns())')
    out=$("$work/a.out")
    end=$(python3 -c 'import time; print(time.time_ns())')
    ms=$(( (end - start) / 1000000 ))
    [ -z "$best" ] || [ "$ms" -lt "$best" ] && best=$ms
    if [ -z "$expect" ]; then expect="$out";
    elif [ "$out" != "$expect" ]; then echo "ZIG CHECKSUM MISMATCH: $out != $expect" >&2; exit 1; fi
    i=$((i + 1))
done
printf 'zig        %6s ms   %s   (whole process, min of 3)\n\n' "$best" "$expect"

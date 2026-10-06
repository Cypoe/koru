#!/usr/bin/env sh
# The LINQ post's headline task on .NET — filter -> map -> sum — raced
# against the canonical C# spellings of the same task. The `generated`
# arm is the real emitted artifact: task.k is compiled with --lang=cs and
# its output_emitted.cs is built INTO the benchmark assembly; the harness
# calls main_module.run_event.handler — the same method a real call site
# invokes. If the emission shape changes, this file stops compiling.
#
# Comparator set, declared before measuring: LINQ on a materialized array
# (its best case), LINQ over the lazy Enumerable.Range source (the true
# source-equivalent — our `for` materializes nothing either), a `yield`
# producer pipeline, a plain foreach over the array, and the fused
# handwritten loop — the atom this task reduces to.
#
# Correctness control: every arm must produce the closed form; a stage
# that never ran shows up as a wrong sum.
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
cp "$ROOT/task.k" "$ROOT/task.kcs" "$work/"

# Emit. koruc writes output_emitted.cs here; the .kcs facet is read from
# the same directory as the .k source.
( cd "$work" && "$KORUC" task.k --lang=cs >/dev/null 2>&1 )
[ -f "$work/output_emitted.cs" ] || { echo "no output_emitted.cs produced" >&2; exit 1; }

# Assemble the benchmark project: harness + the real emitted file.
mkdir -p "$work/proj"
cp "$ROOT/Program.cs" "$ROOT/koru.csproj" "$work/output_emitted.cs" "$work/proj/"

echo
( cd "$work/proj" && dotnet build -c Release -o out >/dev/null )
"$work/proj/out/linq_task"
echo

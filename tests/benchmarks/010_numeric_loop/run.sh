#!/usr/bin/env sh
# Numeric loop on .NET — a generated Koru `for` over N elements doing typed
# math + a state write per element, vs handwritten C# shapes. The
# `generated` arm is the real emitted artifact: loop.k + loop.kcs compile
# with --lang=cs and the output_emitted.cs builds INTO this assembly; the
# harness calls main_module.run_event.handler — the method a real call
# site invokes.
#
# Correctness control: every arm must produce the identical sum — a skipped
# hop or dead loop changes it. `direct-static` isolates the accumulator's
# memory residence (module state is a field, not a register) so dispatch
# cost is not confused with it.
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
cp "$ROOT/loop.k" "$ROOT/loop.kcs" "$work/"

# Emit. koruc writes output_emitted.cs (and its own koru.csproj) here.
( cd "$work" && "$KORUC" loop.k --lang=cs >/dev/null 2>&1 )
[ -f "$work/output_emitted.cs" ] || { echo "no output_emitted.cs produced" >&2; exit 1; }

# Assemble the benchmark project: harness + the real emitted file.
mkdir -p "$work/proj"
cp "$ROOT/Program.cs" "$ROOT/koru.csproj" "$work/output_emitted.cs" "$work/proj/"

echo
( cd "$work/proj" && dotnet build -c Release -o out >/dev/null )
"$work/proj/out/numeric_loop"
echo

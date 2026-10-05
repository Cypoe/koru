#!/usr/bin/env sh
# Effect-branch CHAINING on .NET — a value through K resuming arm hops per
# call, vs the canonical composition idioms (LINQ Select chains, composed
# delegates, virtual stages). The `generated` arm is the real emitted
# artifact: chain.k is compiled with --lang=cs and its output_emitted.cs
# is built INTO the benchmark assembly, then the harness calls
# main_module.chain_event.handler<ChainOps> — the same method a real call
# site invokes, monomorphized on a harness-side ops struct standing in for
# the emitted (private) __koru_handlers_N.
#
# Correctness control: the ops arm increments `fires` on a shared static
# and the harness exits nonzero unless it reports exactly N*K fires — a
# benchmark whose arms do different work measures nothing.
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
cp "$ROOT/chain.k" "$work/"

# Emit. koruc writes output_emitted.cs (and its own koru.csproj) here.
( cd "$work" && "$KORUC" chain.k --lang=cs >/dev/null 2>&1 )
[ -f "$work/output_emitted.cs" ] || { echo "no output_emitted.cs produced" >&2; exit 1; }

# Assemble the benchmark project: harness + the real emitted file.
mkdir -p "$work/proj"
cp "$ROOT/Program.cs" "$ROOT/koru.csproj" "$work/output_emitted.cs" "$work/proj/"

echo
( cd "$work/proj" && dotnet build -c Release -o out >/dev/null )
"$work/proj/out/effect_chaining"
echo

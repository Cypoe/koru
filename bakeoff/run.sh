#!/usr/bin/env sh
# bakeoff — the catch-layer matrix. Same naive bug, four stacks, verbatim logs.
# Every cell is buggy by construction; the verdict is WHERE the mistake is
# caught, not whether. Tiers: refuse (compile) > refuse (runtime) > ships.
set -u

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
KORUC="${KORUC:-$ROOT/../zig-out/bin/koruc}"
OUT="$ROOT/out"
rm -rf "$OUT"
mkdir -p "$OUT"

diag() { grep -m1 -E 'error|panic|Exception|cannot' "$1" 2>/dev/null | sed 's/^ *//' | cut -c1-110; }

printf '| cell | koru | rust | csharp | go |\n|---|---|---|---|---|\n'

for cell_dir in "$ROOT"/cells/*/; do
    cell="$(basename "$cell_dir")"
    row="| $cell "

    # --- koru -------------------------------------------------------------
    log="$OUT/${cell}_koru.log"
    ( cd "$cell_dir" && "$KORUC" koru.k ) > "$log" 2>&1
    if grep -q 'error\[\|Compilation failed\|error:' "$log"; then
        if grep -q 'output_emitted\.zig:[0-9]' "$log"; then
            row="$row| **refuse** (emitted-Zig coords) "
        else
            row="$row| **refuse** (compile) "
        fi
    elif [ -x "$cell_dir/a.out" ]; then
        ( cd "$cell_dir" && ./a.out ) >> "$log" 2>&1
        [ $? -eq 0 ] && row="$row| ships (silent) " || row="$row| **refuse** (runtime) "
    else
        row="$row| (no verdict) "
    fi

    # --- rust -------------------------------------------------------------
    log="$OUT/${cell}_rust.log"
    bin="$OUT/${cell}_rust"
    ( cd "$cell_dir" && rustc --edition 2021 rust.rs -o "$bin" ) > "$log" 2>&1
    if [ ! -x "$bin" ]; then
        row="$row| **refuse** (compile) "
    else
        "$bin" >> "$log" 2>&1
        [ $? -eq 0 ] && row="$row| ships (silent) " || row="$row| refuse (runtime) "
    fi

    # --- csharp -----------------------------------------------------------
    log="$OUT/${cell}_csharp.log"
    ( cd "$cell_dir/csharp" && dotnet build cell.csproj -v q --nologo ) > "$log" 2>&1
    dll="$cell_dir/csharp/bin/Debug/net9.0/cell.dll"
    if [ ! -f "$dll" ]; then
        row="$row| **refuse** (compile) "
    else
        dotnet "$dll" >> "$log" 2>&1
        [ $? -eq 0 ] && row="$row| ships (silent) " || row="$row| refuse (runtime) "
    fi

    # --- go ---------------------------------------------------------------
    log="$OUT/${cell}_go.log"
    bin="$OUT/${cell}_go"
    ( cd "$cell_dir" && go build -o "$bin" go.go ) > "$log" 2>&1
    if [ ! -x "$bin" ]; then
        row="$row| **refuse** (compile) "
    else
        "$bin" >> "$log" 2>&1
        [ $? -eq 0 ] && row="$row| ships (silent) " || row="$row| refuse (runtime) "
    fi

    printf '%s|\n' "$row"
done

printf '\nverbatim logs in %s\n' "$OUT"

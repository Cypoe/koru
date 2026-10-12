#!/bin/bash
# C-lane census probe — one row per regression dir for `koruc --lang=c`.
# Usage: xargs -a dirs.txt -d '\n' -n1 -P4 bash scripts/c_census_probe.sh >> census.tsv
# Env: KORUC (default: koruc on PATH), KORU_TIMEOUT (default 120).
d="$1"
cd "$d" || exit 0
entry=""
[ -f input.k ] && entry=input.k
[ -f input.kz ] && entry=input.kz
[ -z "$entry" ] && { echo -e "$d\tNO_INPUT"; exit 0; }
flags=""
[ -f COMPILER_FLAGS ] && flags=$(head -1 COMPILER_FLAGS)
rm -f output_emitted.c
out=$(timeout "${KORU_TIMEOUT:-120}" "${KORUC:-koruc}" "$entry" --lang=c $flags 2>&1)
rc=$?
if [ -s output_emitted.c ]; then
  line="$d\tEMITTED\t$(wc -c < output_emitted.c)"
elif echo "$out" | grep -q "KORU047"; then
  axes=$(echo "$out" | grep -oE "(effect arms|raw host lines|pump / rings / worker.spawn|NoCProcBody|has no .c proc body|no C type in the first fragment|named branches|wildcard input|subflow impls|unsupported builtin)" | sort -u | tr "\n" "," | sed "s/,$//")
  procs=$(echo "$out" | grep -oE "C lane: [^ ]+ has no .c proc body" | sed "s/C lane: //;s/ has no.*//" | sort -u | tr "\n" "," | sed "s/,$//")
  line="$d\tREFUSED\t$axes\t$procs"
elif echo "$out" | grep -q "KORU121"; then
  ctors=$(echo "$out" | grep -oE 'construct `[^`]+`' | sed 's/construct `//;s/`//' | sort -u | tr "\n" "," | sed "s/,$//")
  line="$d\tREFUSED\tno-c-template\t$ctors"
elif [ $rc -eq 124 ]; then
  line="$d\tTIMEOUT"
else
  code=$(echo "$out" | grep -oE "KORU[0-9]+" | head -1)
  err=$(echo "$out" | grep -oE "error\[[A-Z0-9]+\]: .{0,60}" | head -1)
  line="$d\tFRONTEND\t${code:-rc$rc}\t$err"
fi
# artifacts are regenerable; keep the probe disk-flat
rm -rf .zig-cache zig-out a.out a_c_equiv output_emitted.c output_emitted.zig \
       backend_output_emitted.zig backend.zig build.zig build_backend.zig \
       compiler_env.json program.ast.json actual.c.txt compile_c.err ccomp.err \
       actual.txt actual.zig.txt actual.js.txt actual.cs.txt diff.txt 2>/dev/null
echo -e "$line"

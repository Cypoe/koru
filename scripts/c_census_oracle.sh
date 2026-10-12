#!/bin/bash
# CompCert oracle pass — second sweep over EMITTED dirs from c_census_probe.sh.
# Usage: xargs -a emitted_dirs.txt -d '\n' -n1 -P4 bash scripts/c_census_oracle.sh >> oracle.tsv
# Env: KORUC (default: koruc on PATH), KORU_CC_ORACLE (default ccomp — see tools/tools.json), KORU_TIMEOUT.
d="$1"
cd "$d" || exit 0
entry=""
[ -f input.k ] && entry=input.k
[ -f input.kz ] && entry=input.kz
[ -z "$entry" ] && exit 0
flags=""
[ -f COMPILER_FLAGS ] && flags=$(head -1 COMPILER_FLAGS)
rm -f output_emitted.c a_c_equiv
timeout "${KORU_TIMEOUT:-120}" "${KORUC:-koruc}" "$entry" --lang=c $flags > /dev/null 2>&1
[ -s output_emitted.c ] || { echo -e "$d\tREEMIT_FAILED"; exit 0; }
if timeout 120 "${KORU_CC_ORACLE:-ccomp}" -O -fstruct-passing -Wl,-s -o a_c_equiv output_emitted.c > ccomp.err 2>&1; then
  if timeout 30 ./a_c_equiv > actual.c.txt 2>&1; then
    if [ -f expected.txt ] && cmp -s actual.c.txt expected.txt; then
      echo -e "$d\tCCOMP_OK\tmatch"
    else
      echo -e "$d\tCCOMP_OK\tnorun-exp"
    fi
  else
    echo -e "$d\tCCOMP_OK\trun-failed"
  fi
else
  echo -e "$d\tCCOMP_FAIL\t$(grep -oE 'error[^\n]{0,50}' ccomp.err | head -1)"
fi
rm -rf .zig-cache zig-out a.out a_c_equiv output_emitted.c output_emitted.zig \
       backend_output_emitted.zig backend.zig build.zig build_backend.zig \
       compiler_env.json program.ast.json actual.c.txt ccomp.err 2>/dev/null

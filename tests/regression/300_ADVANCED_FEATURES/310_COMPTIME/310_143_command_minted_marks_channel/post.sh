#!/bin/bash
# The channel must mint input.marks (stem of input.kz) with exactly the two
# well-formed commits — and only those. A malformed field never reaches the
# wire; the exit code is honored after the flush, so the corpus lands even
# on a refused run.
set -e

OUT=$(koruc "$KORU_INPUT" markcmd 2>&1) || true
echo "$OUT" | grep -q "refused-commits=3" || { echo "FAIL: malformed commits not refused"; echo "$OUT"; exit 1; }

[ -f input.marks ] || { echo "FAIL: input.marks not minted"; exit 1; }
grep -q '@witness("admission","demo.iface","koru-native<-none","refused","reason=missing-row")' input.marks \
  || { echo "FAIL: admission mark missing"; cat input.marks; exit 1; }
grep -q '@witness("declaration","demo.mod","decl<-parsed","refused","lacks-iface-or-binds")' input.marks \
  || { echo "FAIL: declaration mark missing"; cat input.marks; exit 1; }
[ "$(grep -c '@witness(' input.marks)" = "2" ] \
  || { echo "FAIL: malformed commits reached the wire"; cat input.marks; exit 1; }
rm -f input.marks

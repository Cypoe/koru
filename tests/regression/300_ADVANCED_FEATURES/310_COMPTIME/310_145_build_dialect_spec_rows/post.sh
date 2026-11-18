#!/bin/bash
# The dialect judge must see every arm: literal atoms, one whole expression
# through the flag provider, and raw residue kept by the row's policy.
set -e

OUT=$(koruc "$KORU_INPUT" cfg --build=dev 2>&1)
echo "$OUT" | grep -q "port=3000" || { echo "FAIL: dev did not resolve port=3000"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "lane=full" || { echo "FAIL: !lean || !race did not keep lane"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "tag=MISSING" || { echo "FAIL: v1.2.3 residue matched without its flag"; echo "$OUT"; exit 1; }

OUT=$(koruc "$KORU_INPUT" cfg --build=prod 2>&1)
echo "$OUT" | grep -q "port=80 " || { echo "FAIL: prod did not resolve port=80"; echo "$OUT"; exit 1; }

# Expression arm: --lean --race flips !lean || !race to false, lane drops.
OUT=$(koruc "$KORU_INPUT" cfg --build=dev --lean --race 2>&1)
echo "$OUT" | grep -q "lane=MISSING" || { echo "FAIL: expression arm did not drop lane"; echo "$OUT"; exit 1; }

# Raw-residue arm: v1.2.3 is not an expression; the dialect's keep policy
# judges it as the atom, so build=v1.2.3 selects it.
OUT=$(koruc "$KORU_INPUT" cfg --build=v1.2.3 2>&1)
echo "$OUT" | grep -q "tag=pinned" || { echo "FAIL: raw residue did not match its flag"; echo "$OUT"; exit 1; }

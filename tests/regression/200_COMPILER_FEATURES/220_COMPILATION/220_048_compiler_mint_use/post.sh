#!/bin/bash
# The mint matrix, sandboxed under KORU_MINT_DIR so the user's real mint
# store (~/.koru/mints) is never touched. Everything happens in mint-work/
# under this test dir so artifacts stay local.
set -u
cd "$(dirname "$0")"
export KORU_MINT_DIR="$PWD/mint-work/store"
rm -rf mint-work
mkdir -p mint-work
cd mint-work

fail() { echo "FAIL: $1"; exit 1; }

# 1. Mint this test's own backend.
koruc "../$KORU_INPUT" mint testmint > mint.log 2>&1 || { cat mint.log; fail "koruc mint failed"; }
[ -f store/testmint/mint.json ] || fail "no mint.json in the store"
[ -x store/testmint/backend ] || fail "no minted backend binary"
SHA=$(python3 -c "import json;print(json.load(open('store/testmint/mint.json'))['sha256'])")
[ -n "$SHA" ] || fail "mint.json carries no sha256"

# 2. A consumer spelling use() bare compiles through the minted backend and
#    produces the same output. NOTE: `import std/compiler` is deliberately
#    absent — importing it pulls the module's comptime surface into the
#    emitted backend and the closure would no longer match (row 4 proves it).
cat > consumer.k <<'KORU'
import std/io

std/compiler:use(testmint)

std/io:print.ln("mint-me")
KORU
koruc consumer.k > use.log 2>&1 || { cat use.log; fail "use() consumer refused"; }
grep -q "Minted backend 'testmint' verified" use.log || fail "minted backend not used"
./a.out > run.out 2>&1 || fail "minted-compiled binary failed"
grep -q "mint-me" run.out || fail "minted-compiled output wrong"

# 3. hash: pin — the manifest's sha256 passes, a wrong pin refuses.
cat > consumer_pin.k <<KORU
import std/io

std/compiler:use(testmint, hash: "$SHA")

std/io:print.ln("mint-me")
KORU
koruc consumer_pin.k > pin.log 2>&1 || { cat pin.log; fail "correct hash pin refused"; }

cat > consumer_badpin.k <<'KORU'
import std/io

std/compiler:use(testmint, hash: "0000000000000000000000000000000000000000000000000000000000000000")

std/io:print.ln("mint-me")
KORU
if koruc consumer_badpin.k > badpin.log 2>&1; then
    fail "wrong hash pin was accepted"
fi
grep -q "does not match pinned hash" badpin.log || { cat badpin.log; fail "wrong-pin refusal text missing"; }

# 4. Coverage: a program whose emitted closure differs — here just an extra
#    comptime-bearing import — is refused, with a re-mint teaching.
cat > consumer_other.k <<'KORU'
import std/io
import std/compiler

std/compiler:use(testmint)

std/io:print.ln("mint-me")
KORU
if koruc consumer_other.k > other.log 2>&1; then
    fail "different-closure program was accepted"
fi
grep -q "does not cover this program" other.log || { cat other.log; fail "coverage refusal text missing"; }

# 5. mint check audits the mint against the live tree — exit 0, all clean.
koruc "../$KORU_INPUT" mint check testmint > check.log 2>&1 || { cat check.log; fail "mint check reported drift"; }
grep -q "fresh" check.log || { cat check.log; fail "mint check verdict not fresh"; }

# Consumer .k files are not gitignored (`!**/*.k` reaches them) — clean the
# workdir on success so a green run leaves no untracked sources behind.
# On failure it stays put: the logs are the evidence.
cd ..
rm -rf mint-work
echo "PASS: mint → use → hash-pin → coverage-refusal → mint check"
exit 0

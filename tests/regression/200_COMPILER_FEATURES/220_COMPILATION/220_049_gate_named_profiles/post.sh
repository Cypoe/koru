#!/bin/bash
# The named-gate matrix. Git-dependent verdicts are driven through
# --repo into scratch repositories the test creates, so the pin does not
# depend on whatever happens to be staged in the enclosing repo.
set -u
cd "$(dirname "$0")"
fail() { echo "FAIL: $1"; exit 1; }

# 1. Bare `gate` lists declared profiles and their membership.
LIST=$(koruc "$KORU_INPUT" gate 2>&1)
echo "$LIST"
echo "$LIST" | grep -qE "dev.*\[advisory\].*4 rows"     || fail "dev profile not listed with 4 rows"
echo "$LIST" | grep -qE "broken.*\[blocking\].*1 row"  || fail "broken profile not listed blocking"
echo "$LIST" | grep -qE "strict.*\[blocking\].*1 row"  || fail "strict profile not listed blocking"

# 2. `gate dev` — advisory profile: the instrument runs, the judged row is
#    reported (skip without a staged diff, UNJUDGED with one — both honest),
#    and the odds modifiers roll deterministically.
DEV=$(koruc "$KORU_INPUT" gate dev 2>&1)
echo "$DEV"
echo "$DEV" | grep -q "check ok    shape-is-named"              || fail "check row did not pass"
echo "$DEV" | grep -qE "judge (skip|UNJUDGED) +prose-rule"      || fail "judged row not reported"
echo "$DEV" | grep -qE "odds miss  never-fires"                 || fail "odds-0 row fired"
echo "$DEV" | grep -qE "odds fire  always-fires"                || fail "odds-100 row missed"
echo "$DEV" | grep -qE "odds fire  always-fires.*check ok  always-fires|check ok    always-fires" || fail "always-fires did not run"

# 3. json verdicts — the machine-readable block.
JSON=$(koruc "$KORU_INPUT" gate dev json 2>&1)
echo "$JSON"
echo "$JSON" | grep -q '"profile":"dev"'                        || fail "json: profile missing"
echo "$JSON" | grep -q '"mode":"advisory"'                      || fail "json: mode missing"
echo "$JSON" | grep -q '"name":"shape-is-named","verdict":"pass"'  || fail "json: pass verdict missing"

# 4. `gate broken` — a failing instrument blocks regardless of stance.
if koruc "$KORU_INPUT" gate broken > broken.log 2>&1; then
    cat broken.log; fail "gate broken exited 0 on a failing check"
fi
cat broken.log
grep -q "check FAIL  always-fails" broken.log                   || fail "check FAIL not reported"
grep -q "blocking violation" broken.log                         || fail "blocking summary missing"

# 5. `gate nosuch` refuses and names the declared set.
if koruc "$KORU_INPUT" gate nosuch > nosuch.log 2>&1; then
    cat nosuch.log; fail "gate nosuch exited 0"
fi
cat nosuch.log
grep -q "no profile named 'nosuch'" nosuch.log                  || fail "unknown-profile refusal missing"
grep -q "declared:" nosuch.log                                  || fail "declared set not named"

# 6. `gate strict` over a scratch repo — a real staged diff makes the
#    judgment row UNJUDGED: enforcing → exit 1; --advisory → exit 0.
rm -rf scratch
mkdir -p scratch
git -C scratch init -q .
git -C scratch config user.email gate@test
git -C scratch config user.name gate-test
git -C scratch commit -qm init --allow-empty

# empty repo: no staged diff → the judged row skips, gate is clean
CLEAN=$(koruc "$KORU_INPUT" gate strict --repo "$PWD/scratch" 2>&1) || fail "empty staged diff did not skip"
echo "$CLEAN"
echo "$CLEAN" | grep -q "judge skip  strict-rule — no staged changes" || fail "judge-skip missing"

echo x > scratch/f.txt
git -C scratch add f.txt

if koruc "$KORU_INPUT" gate strict --repo "$PWD/scratch" > strict.log 2>&1; then
    cat strict.log; fail "enforcing profile exited 0 on UNJUDGED"
fi
cat strict.log
grep -q "judge UNJUDGED strict-rule" strict.log                 || fail "UNJUDGED missing"
grep -q "blocking violation" strict.log                         || fail "enforcement did not block"

SOFT=$(koruc "$KORU_INPUT" gate strict --repo "$PWD/scratch" --advisory 2>&1) || fail "--advisory still blocked"
echo "$SOFT"
echo "$SOFT" | grep -q "advisory" || fail "advisory mode not reported"

rm -rf scratch broken.log nosuch.log strict.log

echo "=== PASS: named gates select rows and enforce ==="

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
echo "$LIST" | grep -qE "clean.*\[blocking\].*1 row"   || fail "clean profile not listed blocking"

# 2. `gate dev` — advisory profile: the instrument runs, the judged row is
#    reported (skip without a staged diff, UNJUDGED with one — both honest),
#    and the odds modifiers roll deterministically.
DEV=$(koruc "$KORU_INPUT" gate dev 2>&1)
echo "$DEV"
echo "$DEV" | grep -q "check ok    shape-is-named"              || fail "check row did not pass"
echo "$DEV" | grep -qE "judge (skip|UNJUDGED) +prose-rule"      || fail "judged row not reported"
echo "$DEV" | grep -qE "odds miss +never-fires"                 || fail "odds-0 row fired"
echo "$DEV" | grep -qE "odds fire +always-fires"                || fail "odds-100 row missed"
echo "$DEV" | grep -qE "check ok +always-fires"                 || fail "always-fires did not run"

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

# 6. `gate strict` over a scratch repo — the judgment row delegates to the
#    profile's judge. The judge is an executable contract: argv is
#    (rule, staged-state), the verdict is the first stdout line —
#    VIOLATION / CLEAN / anything else reads UNJUDGED. These stubs speak
#    the protocol; koru/odds is the real judge.
rm -rf scratch
mkdir -p scratch
git -C scratch init -q .
git -C scratch config user.email gate@test
git -C scratch config user.name gate-test
git -C scratch commit -qm init --allow-empty

# empty repo: no staged diff → the judged row skips, gate is clean
CLEAN0=$(koruc "$KORU_INPUT" gate strict --repo "$PWD/scratch" 2>&1) || fail "empty staged diff did not skip"
echo "$CLEAN0"
echo "$CLEAN0" | grep -q "judge skip  strict-rule — no staged changes" || fail "judge-skip missing"

printf '#!/bin/sh\necho "VIOLATION p=0.87"\n' > scratch/strict-judge
printf '#!/bin/sh\necho "CLEAN p=0.91"\n' > scratch/clean-judge
chmod +x scratch/strict-judge scratch/clean-judge

echo x > scratch/f.txt
git -C scratch add f.txt

# enforcing profile + a VIOLATION verdict → exit 1
if koruc "$KORU_INPUT" gate strict --repo "$PWD/scratch" > strict.log 2>&1; then
    cat strict.log; fail "enforcing profile exited 0 on a judge VIOLATION"
fi
cat strict.log
grep -q "judge VIOLATION strict-rule  VIOLATION p=0.87" strict.log || fail "judge VIOLATION missing"
grep -q "blocking violation" strict.log                            || fail "enforcement did not block"

# the same verdict, softened by --advisory → exit 0
SOFT=$(koruc "$KORU_INPUT" gate strict --repo "$PWD/scratch" --advisory 2>&1) || fail "--advisory still blocked"
echo "$SOFT"
echo "$SOFT" | grep -q "advisory" || fail "advisory mode not reported"

# a CLEAN verdict passes an enforcing profile
CLEAN=$(koruc "$KORU_INPUT" gate clean --repo "$PWD/scratch" 2>&1) || fail "clean profile exited nonzero on CLEAN"
echo "$CLEAN"
echo "$CLEAN" | grep -q "judge ok    clean-rule  CLEAN p=0.91" || fail "judge CLEAN missing"
echo "$CLEAN" | grep -q "enforcing — clean" || fail "clean verdict summary missing"

# a profile with no judge declared is honest about it — UNJUDGED with the
# cause, never a silent pass; --judge-only skips check rows entirely
DEVJ=$(koruc "$KORU_INPUT" gate dev --repo "$PWD/scratch" --judge-only 2>&1)
echo "$DEVJ"
echo "$DEVJ" | grep -q "UNJUDGED prose-rule"                      || fail "no-judge UNJUDGED missing"
echo "$DEVJ" | grep -q 'declares no "judge"'                      || fail "no-judge cause not named"
echo "$DEVJ" | grep -q "check ok" && fail "--judge-only ran a check row"

rm -rf scratch broken.log nosuch.log strict.log

echo "=== PASS: named gates select rows, delegate judgment, and enforce ==="

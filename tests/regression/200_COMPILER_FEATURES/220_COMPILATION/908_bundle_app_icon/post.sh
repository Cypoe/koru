#!/bin/bash
# `icon:` on std/build:app must land the .icns in Contents/Resources and
# name it via CFBundleIconFile (basename minus extension) in the disk
# plist — and the embedded __TEXT,__info_plist must carry the same key,
# or codesign's cross-check would refuse.
set -u
APP="Icon App.app"
rm -rf "$APP" "Missing Icon.app" missing_icon.k missing.log
SCRATCH="$(mktemp -d)"

if ! koruc bundle "$KORU_INPUT" > bundle.log 2>&1; then
    echo "FAIL: koruc bundle refused"
    cat bundle.log
    exit 1
fi

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$APP/Contents/Resources/appicon.icns" ] || fail "no Contents/Resources/appicon.icns"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist")" = "appicon" ] \
    || fail "CFBundleIconFile mismatch"
plutil -lint "$APP/Contents/Info.plist" | grep -q "OK" || fail "Info.plist does not lint"
codesign --verify "$APP" 2> codesign.err || { cat codesign.err; fail "bundle does not verify"; }

# A missing icon file must refuse cleanly, not ship a bundle with a dead
# key. The probe lives in a scratch dir — a stray .k in the test dir is
# picked up by the fixture un-ignores.
cat > "$SCRATCH/missing_icon.k" <<'EOF'
import std/build
import std/io
std/build:app { name: "Missing Icon", id: "org.koru.regtest.iconmissing", icon: "nope.icns" }
std/io:print.ln("x")
EOF
( cd "$SCRATCH" && koruc bundle missing_icon.k ) > missing.log 2>&1 && fail "missing icon was not refused"
grep -q "app icon not found" missing.log || { cat missing.log; fail "wrong refusal for missing icon"; }
[ ! -d "$SCRATCH/Missing Icon.app" ] || fail "refusal still left a bundle"

echo "PASS: Icon App.app — icon in Resources, CFBundleIconFile, signature, missing-icon refusal"
exit 0

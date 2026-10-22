#!/bin/bash
# koru bundle must assemble a real .app from std/build:app — directory
# layout, on-disk Info.plist, executable bit, and a signature whose
# embedded __TEXT,__info_plist agrees with the disk plist.
set -u
APP="Regtest App.app"
rm -rf "$APP"

if ! koruc bundle "$KORU_INPUT" > bundle.log 2>&1; then
    echo "FAIL: koruc bundle refused"
    cat bundle.log
    exit 1
fi

fail() { echo "FAIL: $1"; exit 1; }

[ -d "$APP/Contents/MacOS" ] || fail "no Contents/MacOS"
[ -d "$APP/Contents/Resources" ] || fail "no Contents/Resources"
[ -f "$APP/Contents/Info.plist" ] || fail "no Info.plist"
[ -f "$APP/Contents/PkgInfo" ] || fail "no PkgInfo"
[ "$(cat "$APP/Contents/PkgInfo")" = "APPL????" ] || fail "PkgInfo is not APPL????"
[ -x "$APP/Contents/MacOS/Regtest App" ] || fail "no executable Contents/MacOS/Regtest App"

plutil -lint "$APP/Contents/Info.plist" | grep -q "OK" || fail "Info.plist does not lint"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = "org.koru.regtest.bundle" ] \
    || fail "CFBundleIdentifier mismatch"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")" = "Regtest App" ] \
    || fail "CFBundleExecutable mismatch"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" = "0.2" ] \
    || fail "version mismatch"

codesign --verify "$APP" 2> codesign.err || { cat codesign.err; fail "bundle does not verify"; }

echo "PASS: Regtest App.app — layout, plist, executable, signature all verify"
exit 0

#!/bin/bash
# Debug already ran (MUST_RUN + EXPECT_TRAP): leak check fired, exit 1.
# This half rebuilds the SAME emitted unit at ReleaseFast and demands the
# opposite: exit 0, no leak message. One source, two optimize modes.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi
if ! grep -q 'mode == .Debug' output_emitted.zig; then
    echo "FAIL: emitted source has no Debug mode gate"
    exit 1
fi
if ! grep -q 'koru_leak_check' output_emitted.zig; then
    echo "FAIL: emitted source has no koru_leak_check"
    exit 1
fi

if ! zig build-exe -O ReleaseFast -lc --name output_release output_emitted.zig 2>release_build.err; then
    echo "FAIL: ReleaseFast rebuild of output_emitted.zig failed"
    sed -n '1,20p' release_build.err
    exit 1
fi
set +e
./output_release >release_actual.txt 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "FAIL: ReleaseFast leaked program exited $rc; leak check must fold away"
    cat release_actual.txt
    exit 1
fi
if grep -q "KORU LEAK CHECK FAILED" release_actual.txt; then
    echo "FAIL: ReleaseFast still printed the leak check"
    cat release_actual.txt
    exit 1
fi
echo "PASS: Debug leak-check fired; ReleaseFast folded it"
rm -f output_release output_release.o release_actual.txt release_build.err
rm -rf .zig-cache zig-out
exit 0

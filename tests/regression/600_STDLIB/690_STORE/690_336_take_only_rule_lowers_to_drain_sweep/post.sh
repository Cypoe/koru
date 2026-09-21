#!/bin/bash
# Emitted-shape oracle for the drain lowering. `pool`'s rule body is a
# bare `take(pool[e])` with a discard `| item`, so its invoked sweep is a
# read-only bookkeeping traversal — sequential take's freelist push order
# is provably `row_hslot[0]` then `row_hslot[n-1]` down to `row_hslot[1]`,
# so the lowering reads the original mapping in that order: generation
# bump, hslot_row tombstone, freelist push — no per-row resolve, no
# column reads, no swap-writes. `guarded` carries a `when` clause, so its
# sweep keeps the removal-tolerant `while` that re-checks the index
# swap-remove just refilled.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi

# --- pool lowered to the drain traversal ---
if ! grep -q 'const __koru_dn = __koru_store_pool\.len' output_emitted.zig; then
    echo "FAIL: pool's sweep did not lower to the drain traversal"
    exit 1
fi
if ! grep -q 'for (1\.\.__koru_dn)' output_emitted.zig; then
    echo "FAIL: drain lost the removal-ordered freelist walk"
    exit 1
fi
POOL_SWEEP=$(awk '/qsweep_pool/,/^    };$/' output_emitted.zig)
if ! printf '%s' "$POOL_SWEEP" | grep -q '__koru_hslot_gen\[__koru_slot\] +%= 1'; then
    echo "FAIL: drain lost the generation bump"
    exit 1
fi
if ! printf '%s' "$POOL_SWEEP" | grep -q '__koru_hslot_free_len += 1'; then
    echo "FAIL: drain lost the freelist push"
    exit 1
fi
if printf '%s' "$POOL_SWEEP" | grep -q '__koru_store_pool\.hp\['; then
    echo "FAIL: drain still moves column data — the payload it discards"
    exit 1
fi
if printf '%s' "$POOL_SWEEP" | grep -q '__koru_len_before'; then
    echo "FAIL: pool kept the per-row tolerant loop — drain did not fire"
    exit 1
fi

# --- guarded declined: removal-tolerant while kept for it ---
GUARDED_SWEEP=$(awk '/qsweep_guarded/,/^    };$/' output_emitted.zig)
if ! printf '%s' "$GUARDED_SWEEP" | grep -q '__koru_len_before'; then
    echo "FAIL: guarded sweep lost its removal-tolerant while"
    exit 1
fi

# --- JS lane: same lowering, JS spelling ---
if [ -f output_emitted.js ]; then
    if ! grep -q 'const __koru_dn = __koru_store_pool\.len' output_emitted.js; then
        echo "FAIL: JS lane did not lower pool's sweep to the drain"
        exit 1
    fi
    if ! grep -q '% 2097152' output_emitted.js; then
        echo "FAIL: JS drain lost the 2^21-wrapping generation bump"
        exit 1
    fi
fi

echo "PASS: take-only rule lowers to bookkeeping drain; guarded rule keeps tolerant sweep"
exit 0

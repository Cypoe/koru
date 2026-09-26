#!/bin/bash
# Emitted-shape oracle for the drain lowering. `pool`'s rule body is a
# bare `take(pool[e])` with a discard `| item`, so its invoked sweep is
# the clear unit's canonical reset: every issued slot's generation
# bumps once (`0..hslot_next` covers live rows and slots freed by
# earlier takes), then len, the freelist and the fresh cursor drop to
# zero and `ident` re-arms — no per-row resolve, no column reads, no
# freelist materialization. The observable difference vs a per-row
# take walk is refill pop order: reset reissues slots in fresh order,
# the same slot SET either way. `guarded` carries a `when` clause, so
# its sweep keeps the removal-tolerant `while` that re-checks the index
# swap-remove just refilled.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi

# --- pool lowered to the drain reset ---
if ! grep -q 'const __koru_dn = __koru_store_pool\.len' output_emitted.zig; then
    echo "FAIL: pool's sweep did not lower to the drain reset"
    exit 1
fi
POOL_SWEEP=$(awk '/qsweep_pool/,/^    };$/' output_emitted.zig)
if ! printf '%s' "$POOL_SWEEP" | grep -q '__koru_hslot_gen\[__koru_i\] +%= 1'; then
    echo "FAIL: drain lost the issued-slot generation bump"
    exit 1
fi
if ! printf '%s' "$POOL_SWEEP" | grep -q '__koru_hslot_next = 0'; then
    echo "FAIL: drain did not reset the fresh-slot cursor"
    exit 1
fi
if ! printf '%s' "$POOL_SWEEP" | grep -q '__koru_hslot_free_len = 0'; then
    echo "FAIL: drain did not drop the freelist"
    exit 1
fi
if ! printf '%s' "$POOL_SWEEP" | grep -q '__koru_ident = true'; then
    echo "FAIL: drain did not re-arm the identity map"
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

# --- ipool lowered too: an index decl does not disqualify ---
IPOOL_SWEEP=$(awk '/qsweep_ipool/,/^    };$/' output_emitted.zig)
if ! printf '%s' "$IPOOL_SWEEP" | grep -q 'const __koru_dn = __koru_store_ipool\.len'; then
    echo "FAIL: indexed store's take-only rule did not lower to the drain reset"
    exit 1
fi
if printf '%s' "$IPOOL_SWEEP" | grep -q '__koru_store_ipool\.\(tag\|hp\)\['; then
    echo "FAIL: indexed drain still moves column data"
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
    if ! grep -q '__koru_hslot_next = 0' output_emitted.js; then
        echo "FAIL: JS drain did not reset the fresh-slot cursor"
        exit 1
    fi
fi

echo "PASS: take-only rule lowers to the reset drain; guarded rule keeps tolerant sweep"
exit 0

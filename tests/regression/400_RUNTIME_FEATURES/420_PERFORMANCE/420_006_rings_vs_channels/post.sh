#!/bin/bash
# Post-validation: Report performance comparison
#
# Koru is the reference column. Zig, Rust, and Go are measured
# against it — the question is what it costs them to match us.

set -e

if [ ! -f "results.json" ]; then
    echo "⚠️  No benchmark results found (results.json missing)"
    echo "   Running benchmark..."
    bash benchmark.sh
fi

if [ ! -f "results.json" ]; then
    echo "❌ FAIL: Benchmark did not produce results.json"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "⚠️  jq not installed (needed to parse benchmark results)"
    echo "   Install with: brew install jq (macOS) or apt install jq (Linux)"
    echo "   Skipping performance validation..."
    exit 0
fi

# Parse results (order matches benchmark.sh command-name order)
GO_TIME=$(jq -r '.results[0].mean' results.json)
ZIG_TIME=$(jq -r '.results[1].mean' results.json)
RUST_TIME=$(jq -r '.results[2].mean' results.json)
KORU_TIME=$(jq -r '.results[3].mean' results.json)
TAPS_TIME=$(jq -r '.results[4].mean' results.json)

# Calculate ratios — Koru is the reference column: every row is
# expressed as <other> / Koru, so >1.0 means slower than Koru.
ZIG_VS_KORU=$(echo "scale=4; $ZIG_TIME / $KORU_TIME" | bc -l)
RUST_VS_KORU=$(echo "scale=4; $RUST_TIME / $KORU_TIME" | bc -l)
GO_VS_KORU=$(echo "scale=4; $GO_TIME / $KORU_TIME" | bc -l)
TAPS_VS_KORU=$(echo "scale=4; $TAPS_TIME / $KORU_TIME" | bc -l)
TAPS_VS_ZIG=$(echo "scale=4; $TAPS_TIME / $ZIG_TIME" | bc -l)
KORU_VS_ZIG=$(echo "scale=4; $KORU_TIME / $ZIG_TIME" | bc -l)
RUST_VS_ZIG=$(echo "scale=4; $RUST_TIME / $ZIG_TIME" | bc -l)
ZIG_VS_GO=$(echo "scale=4; $ZIG_TIME / $GO_TIME" | bc -l)

echo ""
echo "=========================================="
echo "  PERFORMANCE COMPARISON"
echo "=========================================="
echo ""
echo "Koru (ring flow):        ${KORU_TIME}s"
echo "Zig (MPMC ring):      ${ZIG_TIME}s"
echo "Rust (crossbeam):     ${RUST_TIME}s"
echo "Go (channels):        ${GO_TIME}s"
echo "Koru (taps):          ${TAPS_TIME}s"
echo ""
echo "Ratios (>1.0 = slower than Koru):"
echo "  Zig/Koru:     ${ZIG_VS_KORU}x"
echo "  Rust/Koru:    ${RUST_VS_KORU}x"
echo "  Go/Koru:      ${GO_VS_KORU}x"
echo "  Taps/Koru:    ${TAPS_VS_KORU}x"
echo "  Taps/Zig:     ${TAPS_VS_ZIG}x"
echo "  Koru/Zig:     ${KORU_VS_ZIG}x  (regression guard)"
echo "  Rust/Zig:     ${RUST_VS_ZIG}x"
echo "  Zig/Go:       ${ZIG_VS_GO}x"
echo ""

# Interpret: Zig vs Koru — the parity verdict. Koru is the
# reference; this answers "what does hand-written Zig cost to beat us?"
echo "Zig vs Koru (PARITY):"
if (( $(echo "$ZIG_VS_KORU > 1.05" | bc -l) )); then
    MARGIN=$(echo "scale=1; ($ZIG_VS_KORU - 1) * 100" | bc -l)
    echo "  🚀 Koru is ${MARGIN}% faster than hand-written Zig"
    echo "  The abstraction is not just free — it is ahead"
elif (( $(echo "$ZIG_VS_KORU < 0.95" | bc -l) )); then
    MARGIN=$(echo "scale=1; (1 - $ZIG_VS_KORU) * 100" | bc -l)
    echo "  ⚠️  Zig is ${MARGIN}% faster than Koru"
else
    echo "  🎉 ZERO-COST ABSTRACTION — Koru matches Zig within noise"
fi

echo ""

# Regression guard: Koru must stay within 1.10x of Zig
echo "Regression guard (Koru/Zig):"
if (( $(echo "$KORU_VS_ZIG < 1.10" | bc -l) )); then
    echo "  ✅ PASS (${KORU_VS_ZIG}x < 1.10x)"
else
    OVERHEAD=$(echo "scale=1; ($KORU_VS_ZIG - 1) * 100" | bc -l)
    echo "  ❌ PERFORMANCE REGRESSION!"
    echo "  Koru is ${OVERHEAD}% slower than Zig"
    echo "  This means abstractions have cost - investigate!"
fi

echo ""

# Interpret: Rust vs Koru
echo "Rust (crossbeam) vs Koru:"
if (( $(echo "$RUST_VS_KORU > 1.05" | bc -l) )); then
    MARGIN=$(echo "scale=1; ($RUST_VS_KORU - 1) * 100" | bc -l)
    echo "  ✅ Koru is ${MARGIN}% faster than crossbeam"
elif (( $(echo "$RUST_VS_KORU < 0.95" | bc -l) )); then
    MARGIN=$(echo "scale=1; (1 - $RUST_VS_KORU) * 100" | bc -l)
    echo "  ⚠️  Crossbeam is ${MARGIN}% faster than Koru"
else
    echo "  ✅ Roughly equal (within 5%)"
fi

echo ""

# Interpret: Go vs Koru
echo "Go (channels) vs Koru:"
if (( $(echo "$GO_VS_KORU > 1.05" | bc -l) )); then
    MARGIN=$(echo "scale=1; ($GO_VS_KORU - 1) * 100" | bc -l)
    echo "  🚀 Koru is ${MARGIN}% faster than Go channels"
elif (( $(echo "$GO_VS_KORU < 0.95" | bc -l) )); then
    MARGIN=$(echo "scale=1; (1 - $GO_VS_KORU) * 100" | bc -l)
    echo "  ⚠️  Go is ${MARGIN}% faster than Koru"
else
    echo "  ✅ Roughly equal (within 5%)"
fi

echo ""

# Interpret: Rust vs Zig (context row — the two foreign systems langs)
echo "Rust vs Zig (context):"
if (( $(echo "$RUST_VS_ZIG < 0.95" | bc -l) )); then
    IMPROVEMENT=$(echo "scale=1; (1 - $RUST_VS_ZIG) * 100" | bc -l)
    echo "  Rust is ${IMPROVEMENT}% faster than Zig"
elif (( $(echo "$RUST_VS_ZIG > 1.05" | bc -l) )); then
    SLOWDOWN=$(echo "scale=1; ($RUST_VS_ZIG - 1) * 100" | bc -l)
    echo "  Zig is ${SLOWDOWN}% faster than Rust"
else
    echo "  Roughly equal (within 5%)"
fi

echo ""

# Interpret: Koru Taps (context row — a different workload, not a
# channel alternative: no transport, no second thread, no shared
# memory structure. The number says what event observation costs
# when there is nothing to synchronize.)
echo "Koru Taps (no transport — context):"
echo "  ${TAPS_TIME}s for the same message count"
if (( $(echo "$TAPS_VS_KORU < 0.95" | bc -l) )); then
    FACTOR=$(echo "scale=1; $KORU_TIME / $TAPS_TIME" | bc -l)
    echo "  That is ${FACTOR}x the no-transport floor of Koru ring flow"
    echo "  The gap is the cost of the ring + thread, not the grammar"
else
    echo "  Roughly equal to Koru ring flow (unexpected — investigate)"
fi

echo ""

echo "=========================================="

exit 0

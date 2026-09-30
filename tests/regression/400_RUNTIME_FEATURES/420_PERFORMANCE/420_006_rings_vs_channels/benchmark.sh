#!/bin/bash
# Benchmark: Concurrent Message Passing
# Compare Go channels vs Zig MPMC rings vs Rust channels vs Koru ring flow
#
# Tests:
# - Go: Buffered channels (idiomatic Go)
# - Zig: MPMC ring (Vyukov's lock-free algorithm)
# - Rust: Crossbeam bounded channels (lock-free)
# - Koru: MPMC ring fed by a spawned host thread, flow consumer
#
# All send/receive 10M messages between producer/consumer threads.
# Koru is the reference column; the guard is Koru/Zig < 1.10.
#
# (The bchan MPSC leg referenced by the original script was never committed —
# vendor_bchan is an empty gitlink and baseline_bchan.zig never existed.
# The old "Koru taps" leg measured a single-threaded count loop — a
# different workload with no transport, not a comparable channel.)

set -e

echo "============================================"
echo "  CONCURRENT MESSAGE PASSING BENCHMARK"
echo "  Koru vs Zig vs Rust vs Go"
echo "============================================"
echo ""

# Clean up previous builds
rm -f go_baseline zig_baseline rust_baseline koru_output backend backend.zig output_emitted.zig results.json
rm -rf zig-out .zig-cache target Cargo.lock

echo "Building Go baseline (channels)..."
go build -o go_baseline baseline.go

echo "Building Zig baseline (MPMC ring)..."
zig build-exe baseline.zig -O ReleaseFast -femit-bin=zig_baseline

echo "Building Rust baseline (crossbeam channels)..."
cargo build --release --quiet
cp target/release/rust_baseline ./rust_baseline

echo "Building Koru version (MPMC ring + spawned producer)..."
koruc build --release=fast "${KORU_INPUT:-input.kz}"
mv a.out koru_output

echo ""
echo "Running benchmarks with hyperfine..."
echo ""

# Check if hyperfine is installed
if ! command -v hyperfine &> /dev/null; then
    echo "ERROR: hyperfine not installed"
    echo "Install with: brew install hyperfine (macOS) or cargo install hyperfine"
    exit 1
fi

# Run benchmark
# - warmup: 3 runs to stabilize (message passing can vary)
# - runs: 10 (fewer than simple loop since this takes longer)
# - shell=none: avoid shell overhead
hyperfine --warmup 3 --runs 10 --shell=none \
    --export-json results.json \
    --command-name "Koru (ring flow)" './koru_output' \
    --command-name "Zig (MPMC)" './zig_baseline' \
    --command-name "Rust (crossbeam)" './rust_baseline' \
    --command-name "Go (channels)" './go_baseline'

echo ""
echo "============================================"
echo "Benchmark complete! Results saved to results.json"
echo "============================================"

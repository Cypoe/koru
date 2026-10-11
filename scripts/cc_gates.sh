#!/bin/bash
# cc_gates.sh — the K1 gate battery for the C (CompCert) emit target.
# docs/koru-verification-path.md §1: canonical cells G-CC-1..4.
#
#   G-CC-1  equivalence — both backends, stdout bytes + rc (per-test `c` leg
#           in scripts/regression_lib.sh:regression_check_c_equivalence)
#   G-CC-2  missing oracle = FAIL naming the oracle path — never SKIP
#   G-CC-3  refusal tests — every out-of-scope construct refuses by name
#   G-CC-4  determinism pin — pinned ccomp + flags ⇒ byte-identical binary
#
# Honesty contract (the doc's own policy): a missing oracle FAILS loudly and
# names the resolved path — this script never SKIPs a gate, never reports a
# pass it did not run. Exit 0 only when every gate it ran is green.
#
# Usage:
#   ./scripts/cc_gates.sh            # run all four gates
#   ./scripts/cc_gates.sh G-CC-2     # run one gate
#
# Oracle resolution: ${KORU_CC_ORACLE:-ccomp} — an absolute path or a PATH
# lookup. The pinned toolchain (versions + sha256) lives in tools/tools.json.

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CCOMP_BIN="${KORU_CC_ORACLE:-ccomp}"
CC_FIXTURE_DIR="$REPO_ROOT/tools/cc-fixtures"
TOOLS_JSON="$REPO_ROOT/tools/tools.json"
GATES_RUN=0
GATES_FAILED=0

fail_gate() {
    # $1 = gate id, $2 = axis the failure names
    echo -e "${RED}  ✗ $1: FAIL — $2${NC}"
    GATES_FAILED=$((GATES_FAILED + 1))
}

pass_gate() {
    echo -e "${GREEN}  ✓ $1: PASS — $2${NC}"
}

# ---------------------------------------------------------------------------
# G-CC-2: the oracle must exist and answer. A missing oracle is the loudest
# possible failure — it names the path it resolved against.
# ---------------------------------------------------------------------------
g_cc_2() {
    GATES_RUN=$((GATES_RUN + 1))
    echo -e "${CYAN}G-CC-2 oracle presence${NC}"
    if ! command -v "$CCOMP_BIN" >/dev/null 2>&1; then
        fail_gate "G-CC-2" "missing oracle: ccomp not found at '$CCOMP_BIN' (set KORU_CC_ORACLE; install per tools/tools.json)"
        return 1
    fi
    local ver
    ver=$("$CCOMP_BIN" -version 2>&1 | head -1)
    if [ -z "$ver" ]; then
        fail_gate "G-CC-2" "oracle at '$CCOMP_BIN' did not answer -version"
        return 1
    fi
    pass_gate "G-CC-2" "ccomp at $(command -v "$CCOMP_BIN") — $ver"
    return 0
}

# ---------------------------------------------------------------------------
# G-CC-4: determinism pin. Same input + pinned flags ⇒ byte-identical binary.
# Also pins the oracle's own digest against tools/tools.json when recorded.
# ---------------------------------------------------------------------------
g_cc_4() {
    GATES_RUN=$((GATES_RUN + 1))
    echo -e "${CYAN}G-CC-4 determinism pin${NC}"
    if ! command -v "$CCOMP_BIN" >/dev/null 2>&1; then
        fail_gate "G-CC-4" "missing oracle: ccomp not found at '$CCOMP_BIN'"
        return 1
    fi
    local fixture="$CC_FIXTURE_DIR/gate_pin.c"
    if [ ! -f "$fixture" ]; then
        fail_gate "G-CC-4" "missing fixture: $fixture"
        return 1
    fi
    # Pinned flags: CompCert's deterministic subset — no optional passes that
    # consult the environment. `-Wl,-s` strips the symbol table: ccomp feeds
    # the linker a tempfile whose random suffix lands in the binary as an
    # STT_FILE symbol (`compcert<rand>.o`), the one observed nondeterminism
    # source in a 3.18 link. Flags live here, version lives in tools.json.
    local flags="-O -Wl,-s"
    local out1 out2
    out1=$(mktemp) ; out2=$(mktemp)
    if ! "$CCOMP_BIN" $flags -o "$out1" "$fixture" > /dev/null 2>&1; then
        rm -f "$out1" "$out2"
        fail_gate "G-CC-4" "ccomp refused the pin fixture (flags: $flags)"
        return 1
    fi
    if ! "$CCOMP_BIN" $flags -o "$out2" "$fixture" > /dev/null 2>&1; then
        rm -f "$out1" "$out2"
        fail_gate "G-CC-4" "ccomp refused the pin fixture on second run"
        return 1
    fi
    local h1 h2
    h1=$(sha256sum "$out1" | cut -d' ' -f1)
    h2=$(sha256sum "$out2" | cut -d' ' -f1)
    rm -f "$out1" "$out2"
    if [ "$h1" != "$h2" ]; then
        fail_gate "G-CC-4" "same input+flags produced differing binaries ($h1 vs $h2)"
        return 1
    fi
    # Pin the oracle binary digest against tools.json when a digest is on file.
    if [ -f "$TOOLS_JSON" ]; then
        local pinned actual
        pinned=$(node -e 'const t=require(process.argv[1]);const r=(t.tools||[]).find(x=>x.tool==="ccomp");if(r&&r.sha256)console.log(r.sha256)' "$TOOLS_JSON" 2>/dev/null)
        if [ -n "$pinned" ]; then
            actual=$(sha256sum "$(command -v "$CCOMP_BIN")" | cut -d' ' -f1)
            if [ "$actual" != "$pinned" ]; then
                fail_gate "G-CC-4" "oracle digest drift: tools.json pins $pinned, $(command -v "$CCOMP_BIN") is $actual"
                return 1
            fi
            pass_gate "G-CC-4" "byte-identical fixture binary ($h1); oracle digest matches tools.json pin"
            return 0
        fi
    fi
    pass_gate "G-CC-4" "byte-identical fixture binary ($h1); no oracle digest pinned in tools.json yet"
    return 0
}

# ---------------------------------------------------------------------------
# G-CC-1 + G-CC-3: the per-test legs live in the regression suite — every test
# dir under tests/regression whose LANGUAGES marker lists `c`. Equivalence and
# refusals share one mechanism (regression_check_c_equivalence); this gate
# enumerates the opted-in cells and runs them through the suite so the verdict
# is the suite's, not a second implementation's.
# ---------------------------------------------------------------------------
g_cc_1_3() {
    GATES_RUN=$((GATES_RUN + 1))
    echo -e "${CYAN}G-CC-1 equivalence + G-CC-3 refusals (via suite cells)${NC}"
    local tests=()
    while IFS= read -r f; do
        if grep -qiw 'c' "$f" 2>/dev/null; then
            tests+=("$(basename "$(dirname "$f")")")
        fi
    done < <(find "$REPO_ROOT/tests/regression" -name LANGUAGES)
    if [ ${#tests[@]} -eq 0 ]; then
        fail_gate "G-CC-1/3" "no LANGUAGES cells list 'c' — the battery is empty, and an empty battery cannot be green"
        return 1
    fi
    echo "  cells: ${tests[*]}"
    if ! command -v "$CCOMP_BIN" >/dev/null 2>&1; then
        fail_gate "G-CC-1/3" "missing oracle: ccomp not found at '$CCOMP_BIN' — positive cells will fail c-oracle, refusal cells may still pin"
    fi
    ( cd "$REPO_ROOT" && ./run_regression.sh "${tests[@]}" )
    local rc=$?
    if [ $rc -ne 0 ]; then
        fail_gate "G-CC-1/3" "suite reported red cells (rc=$rc)"
        return 1
    fi
    pass_gate "G-CC-1/3" "${#tests[@]} cell(s) green under the suite"
    return 0
}

# ---------------------------------------------------------------------------
main() {
    local only="${1:-all}"
    echo -e "${CYAN}koru ccomp gate battery — $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null) on $(git -C "$REPO_ROOT" branch --show-current 2>/dev/null)${NC}"
    case "$only" in
        all)
            g_cc_2
            g_cc_4
            g_cc_1_3
            ;;
        G-CC-2) g_cc_2 ;;
        G-CC-4) g_cc_4 ;;
        G-CC-1|G-CC-3|G-CC-1_3) g_cc_1_3 ;;
        *) echo "unknown gate: $only (want: all, G-CC-2, G-CC-4, G-CC-1_3)"; exit 2 ;;
    esac
    echo ""
    if [ "$GATES_FAILED" -gt 0 ]; then
        echo -e "${RED}$GATES_FAILED of $GATES_RUN gates FAILED${NC}"
        exit 1
    fi
    echo -e "${GREEN}all $GATES_RUN gates PASS${NC}"
    exit 0
}

main "$@"

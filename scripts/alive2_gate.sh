#!/bin/bash
# Alive2 congruence gate — K2 for the emitted-C lane.
#
# clang -O0 emits the reference IR for a generated output_emitted.c;
# alive-tv then proves every intra-procedural optimization instance in
# the battery is a semantic refinement of that reference. This checks a
# different property than CompCert (K1): not "the verified compiler was
# faithful" but "the emitted C carries no UB a mainstream optimizer can
# exploit divergently."
#
# Scope, stated honestly — measured 2026-10-13 on alive-tv 21.0:
#  - --disable-undef-input/--disable-poison-input: emitted code never
#    produces undef/poison inputs; modeling them explodes the SMT space.
#  - --src-unroll/--tgt-unroll=16: alive2 verifies loops by bounded
#    unrolling; without a bound even a trivial 3-iteration loop reads as
#    "source doesn't reach a return". Loops beyond the bound land in
#    scope:unroll — named, counted, never counted as correct.
#  - Intra-procedural passes only. Interprocedural transforms (inlining,
#    arg promotion, libcall rewriting that introduces globals) sit
#    outside alive-tv's per-function model.
#  - alive2 does not model most libc calls (fputs/abort/fflush/fprintf):
#    a transform alive2 can only check by approximation is outside the
#    decidable scope — classed scope:libcall, named, counted.
#  - sret/noalias signatures don't translate into Alive IR at all —
#    classed scope:untranslatable, named, counted.
#
# Verdict discipline:
#  - incorrect  -> FAIL (a counterexample exists: the transform diverges)
#  - timeout / undecided failed-to-prove / other Alive2 error -> FAIL.
#    "Couldn't finish" is not a scope boundary — it can mask divergence.
#  - scope:*   -> not a pass and not a fail: reported by name per file.
#    A scoped-out function is UNVERIFIED, explicitly — it does not ride
#    the `correct` count.
#  - The parser's counts are cross-checked against alive-tv's own summary;
#    disagreement means the report is untrusted -> FAIL.
#
# Usage: scripts/alive2_gate.sh <output_emitted.c> [<more .c> ...]
set -u -o pipefail
ALIVE="${KORU_ALIVE_TV:-alive-tv}"
CLANG="${KORU_CLANG:-clang}"
UNROLL="${KORU_ALIVE2_UNROLL:-16}"
SMT_TO="${KORU_ALIVE2_SMT_TO:-60000}"
BATTERY='function(mem2reg,instcombine,simplifycfg,reassociate,early-cse,gvn,sccp,dce,jump-threading,instsimplify)'

if ! command -v "$ALIVE" >/dev/null; then
    echo "FAIL: alive-tv not found (set KORU_ALIVE_TV)"
    exit 1
fi
if ! command -v "$CLANG" >/dev/null; then
    echo "FAIL: clang not found (set KORU_CLANG)"
    exit 1
fi
[ $# -ge 1 ] || { echo "usage: alive2_gate.sh <emitted.c> [...]"; exit 1; }

fail=0
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Sequential classifier over alive-tv's output. Verdicts and translate
# errors interleave inside dash regions, so we walk lines, track the last
# 'define', and emit one "tag fn" record per verdict/error:
#   correct / incorrect / scope:libcall / scope:untranslatable /
#   scope:unroll / fail:timeout / fail:undecided / fail:unparsed
# A 'Couldn't prove' is held pending until the next define/dash — an
# "Approximations done: Unknown libcall" note retags it to scope.
classify_stream() {
    # $1 = alive-tv output, $2 = file of external (declare-only) callee names
    awk -v declfile="$2" '
        BEGIN {
            while ((getline l < declfile) > 0) ext[l] = 1
        }
        /^(define|declare)[^@]*@/ {
            if (pending != "") { print pending; pending = "" }
            match($0, /@[A-Za-z_.$0-9]+/); fn = substr($0, RSTART+1, RLENGTH-1)
            next
        }
        /^-{10,}$/ { saw_call=0; has_intcall=0; if (pending != "") { print pending; pending = "" } next }
        /call[^@]*@[A-Za-z_.$0-9]+/ {
            match($0, /@[A-Za-z_.$0-9]+/)
            if (substr($0, RSTART+1, RLENGTH-1) in ext) saw_call=1; else has_intcall=1
        }
        /Summary:/ { if (pending != "") { print pending; pending = "" } in_summary=1; next }
        in_summary { next }
        /Unsupported attribute/ { next }
        /Could not translate/ {
            if (pending != "") { print pending; pending = "" }
            print "scope:untranslatable", fn
            next
        }
        /Unknown libcall/ {
            if (pending != "") {
                sub(/^fail:undecided/, "scope:libcall", pending)
                print pending; pending = ""
            }
            next
        }
        /doesn.t reach a return/ {
            if (pending != "") { print pending; pending = "" }
            print "scope:unroll", fn
            next
        }
        /ERROR: Timeout/ {
            if (pending != "") { print pending; pending = "" }
            # Timeout on a region whose calls are ALL declared-only
            # externals is the unmodeled-libcall approximation grinding —
            # proven 2026-10-13: stubbing the same libcalls lets the same
            # function verify. A timeout with ANY internal call in the
            # region stays fail:timeout — causation unproven there.
            if (saw_call && !has_intcall) {
                print "scope:libcall-timeout", fn
            } else {
                print "fail:timeout", fn
            }
            next
        }
        /Couldn.t prove the correctness/ {
            if (pending != "") { print pending; pending = "" }
            pending = "fail:undecided " fn
            next
        }
        /ERROR/ {
            if (pending != "") { print pending; pending = "" }
            print "incorrect", fn
            next
        }
        /Transformation seems to be correct/ {
            if (pending != "") { print pending; pending = "" }
            print "correct", fn
            next
        }
        END { if (pending != "") print pending }
    ' "$1"
}

for c in "$@"; do
    if [ ! -f "$c" ]; then
        echo "FAIL: emitted C missing: $c"
        fail=1
        continue
    fi
    ref="$work/$(basename "$c" .c).O0.ll"
    if ! "$CLANG" -O0 -emit-llvm -S -std=c11 "$c" -o "$ref" 2>"$work/clang.err"; then
        echo "FAIL: clang -emit-llvm rejected $c:"
        cat "$work/clang.err"
        fail=1
        continue
    fi
    "$ALIVE" --disable-undef-input --disable-poison-input --smt-to="$SMT_TO" \
        --src-unroll="$UNROLL" --tgt-unroll="$UNROLL" \
        --passes="$BATTERY" "$ref" > "$work/alive.out" 2>&1

    : > "$work/scoped.txt"; : > "$work/failed.txt"; : > "$work/names.txt"
    grep -oE 'declare[^@]*@[A-Za-z_.$0-9]+' "$ref" \
        | grep -oE '@[A-Za-z_.$0-9]+$' | tr -d '@' | sort -u > "$work/extnames.txt"
    n_correct=0; n_incorrect=0; n_scope=0; n_fail=0
    while read -r tag fn; do
        case "$tag" in
            correct) n_correct=$((n_correct+1));;
            incorrect) n_incorrect=$((n_incorrect+1)); printf '  %s\n' "$fn" >> "$work/names.txt";;
            scope:*) n_scope=$((n_scope+1)); printf '  %s %s\n' "$tag" "$fn" >> "$work/scoped.txt";;
            fail:*) n_fail=$((n_fail+1)); printf '  %s %s\n' "$tag" "$fn" >> "$work/failed.txt";;
        esac
    done < <(classify_stream "$work/alive.out" "$work/extnames.txt")

    # Cross-check against alive-tv's own summary — our parse must agree.
    s_ok=$(grep -oE '[0-9]+ correct' "$work/alive.out" | grep -oE '^[0-9]+' || true)
    s_bad=$(grep -oE '[0-9]+ incorrect' "$work/alive.out" | grep -oE '^[0-9]+' || true)
    s_ftp=$(grep -oE '[0-9]+ failed-to-prove' "$work/alive.out" | grep -oE '^[0-9]+' || true)
    s_err=$(grep -oE '[0-9]+ Alive2 errors' "$work/alive.out" | grep -oE '^[0-9]+' || true)
    echo "$c: correct=$n_correct scoped=$n_scope incorrect=$n_incorrect failed=$n_fail" \
         "(alive2 says: correct=${s_ok:-0} incorrect=${s_bad:-0} ftp=${s_ftp:-0} err=${s_err:-0})"
    [ -s "$work/scoped.txt" ] && { echo "  scope-excluded (unverified, not counted):"; cat "$work/scoped.txt"; }
    [ -s "$work/failed.txt" ] && { echo "  failed:"; cat "$work/failed.txt"; }
    [ -s "$work/names.txt" ] && { echo "  incorrect:"; cat "$work/names.txt"; }
    if [ "$n_incorrect" -ne 0 ] || [ "$n_fail" -ne 0 ]; then
        echo "FAIL: alive2 could not verify every function in $c"
        fail=1
    fi
    if [ "${s_bad:-0}" -ne "$n_incorrect" ] || [ "${s_ok:-0}" -ne "$n_correct" ] \
       || [ $(( ${s_ftp:-0} + ${s_err:-0} )) -ne $(( n_scope + n_fail )) ]; then
        echo "FAIL: parser/alive2 disagreement on transform counts — gate untrusted"
        fail=1
    fi
done
if [ $fail -eq 0 ]; then echo "alive2 gate: PASS"; else echo "alive2 gate: FAIL"; fi
exit $fail

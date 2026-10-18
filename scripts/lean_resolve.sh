# Shared LEAN resolution for the *_gate.sh scripts.
#
# Order: KORU_LEAN env, the pinned elan path (Lars's box), installed elan
# toolchains — v4.31.0 first (the version the checkers were written
# against), newest after — then PATH (the elan shim may resolve a version
# it must download; last resort).
resolve_lean() {
    if [ -n "${KORU_LEAN:-}" ]; then LEAN="$KORU_LEAN"; return; fi
    LEAN=/home/cypoe/.elan/toolchains/leanprover--lean4---v4.31.0/bin/lean
    if [ ! -x "$LEAN" ]; then
        for cand in "$HOME/.elan/toolchains/leanprover--lean4---v4.31.0/bin/lean" \
                    $(ls -d "$HOME"/.elan/toolchains/leanprover--lean4---v*/bin/lean 2>/dev/null | sort -rV); do
            [ -x "$cand" ] && LEAN="$cand" && break
        done
    fi
    [ -x "$LEAN" ] || LEAN="$(command -v lean || true)"
}

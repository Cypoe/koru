// 330_145 — ambient borrow inside an event arm after the discharger takes it
//
// `pump(w)` takes `*Win<!opened|!active>` — w's obligations move into the
// event loop's custody for its lifetime. Inside `! tick` the program reads
// `w` — the ambient capture. Today's verdict is KORU030 use-after-discharge,
// unconditionally, in this minimal shape.
//
// The friction: spec_sel_live.k (koru-libs/clay/tests) compiles the SAME
// shape — `frames(win: w)` then `window.size(win: w)` inside `! frame` —
// when a `w`-derived binding (`texh` from `image.load(win: w)`) is also
// captured into the arm. So the verdict flips on an unrelated binding's
// presence in the capture set — the capture analysis is non-compositional.
//
// Open semantics question, pinned for the fix: either ambient captures into
// event arms carry their pre-call state (this test should pass) or they
// must route through the arm payload (then the app shape is under-strict
// and this test flips to MUST_ERROR). Either way the verdict must not
// depend on which OTHER bindings are captured.
//
// Surfaced wiring libs/metal:image.load into the OMNI spike; see
// koru-libs/clay/tests/FLOW_BINDINGS.md §3 for the full control matrix.
import app/win
import std/io

app/win:open()
| win w |> app/win:pump(w)
    ! tick _ |> app/win:read(w)
    | done w2 |> app/win:close(w: w2)
| err e |> std/io:print.ln(e)

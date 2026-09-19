---
type: belief
id: frag-the-optional-wrap-stops-at-phantom-args
provenance: the intranquil-domain session flow (tests/session.k, 2026-09) could not pass a held *TempoTrack<live!> to a ?*TempoTrack<live> parameter — every existing test omits the argument, so the hole was unexercised until a wild flow wrote the natural call.
ts: 2026-09-22
---

# ?T coercion fires for scalars and stops at phantom-typed pointers — an asymmetry measured, not designed

`?i32` accepts `i32` — the optional wrap on arguments is implemented. But
`?*T<live>` rejects `*T<live!>` with KORU030 type mismatch: the coercion
path that wraps a plain value in its optional never fires when the argument
carries a phantom state. The whole-catalog consequence in intranquil-domain
was that `?*TempoTrack<live>` parameters are omission-only — the declared
contract says "optional," the checker enforces "absent."

The asymmetry is what makes this a defect rather than a choice: the wrap
exists, it just stops at the type constructor the DAW surface uses most.
Two sub-questions the pin does not pre-judge: whether the wrap should also
shed the `!` obligation marker on the borrowed view (the natural reading —
the borrow leaves the obligation with the caller), and whether `*T<live>`
without `!` hits the same wall. Pinned red aspirational:
`921_optional_borrow_takes_held_token`.

Related:
[[frag-phantom-bind-chain-threading]] — the obligation side of the same
parameter handshake; this is the coercion side.

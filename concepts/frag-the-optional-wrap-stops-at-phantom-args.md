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

Second surface, measured by the WO-012 cell the same day: the omission is
also compulsory — `?*Section<live>` refuses a `null` literal outright
("argument has no tracked phantom state"), because validateArgument
requires every argument to be a tracked binding and null is no binding.
Two different code paths, one user-facing defect: an optional phantom
parameter accepts exactly nothing at the call site.

The asymmetry is what made this a defect rather than a choice: the wrap
existed, it just stopped at the type constructor the DAW surface uses most.
Fixed 2026-09-22 at the two refusal sites — `bareTypeName`/`baseTypesMatch`
now strip `?` (with an asymmetric guard: `?*T` provided into a required `*T`
still refuses, matching the coercion Zig would reject) and `validateArgument`
accepts a `null` literal into any optional-typed param before demanding a
tracked binding. The `!` obligation stays with the caller through the borrow
— only `<!state>` params consume — so a held token can be shown optional-
borrowed and discharged later. Pin `921_optional_borrow_takes_held_token`
green; the real consumer, intranquil-domain `tests/arrangement.k`, went
green on the same build.

Related:
[[frag-phantom-bind-chain-threading]] — the obligation side of the same
parameter handshake; this is the coercion side.

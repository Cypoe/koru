---
type: belief
id: frag-an-arm-used-as-a-value-is-a-handler-path-contract
provenance: metal `frames` `frame_cb = frame` leaked undeclared `frame`
  through the inline splice; the 400_168 gate only covered `! ?` arms;
  generalized and pinned 400_215, 2026-10-18
ts: 2026-10-18
---

# An arm used as a value is a handler-path contract

A `~proc|zig` body may do two things with a `!` arm: call it
(`frame(&__f)`) or hold it (`frame_cb = frame`). The inline splice lowers
only the call — a bare arm name lands in the emitted Zig verbatim and dies
as `use of undeclared identifier`. The handler-call path gives every arm a
real fn value (`const NAME = __H.NAME` for required arms, the nullable
alias for `! ?` optional arms), so both spellings resolve.

So `inlineEffectfulEligibility` must refuse the splice whenever ANY arm
appears in value position — not only the optional ones. 400_168 pinned the
optional case (`if (ready) |f| f()`); the required case waited until
metal's `frames` registered `! frame` on `frame_cb` for the live-resize
redraw. Same leak, same fix: the body stays on the path where the arm is
a value.

Rule of thumb: the splice speaks calls. Anything else a body does with an
arm — assign it, pass it, probe it — needs the handler path.

Pin: 400_215.

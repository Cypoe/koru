; K2 negative control — the gate must prove it can disagree.
; src: input_wmul multiplies. A forged "optimized" target that replaces the
; multiply with an add is NOT a refinement — alive-tv must report it
; `incorrect`. If this pair ever verifies, the battery is lying about its
; own discrimination and every `correct` count above it is suspect.
define i32 @input_wmul(i32 %x, i32 %y) {
  %r = mul i32 %x, %y
  ret i32 %r
}

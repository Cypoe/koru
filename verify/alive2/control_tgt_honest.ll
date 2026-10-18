; honest target: genuinely equivalent (mul x,y == mul y,x at i32 — the
; optimizer's commutativity instance). Must verify `correct`, else the
; control itself is too strict and its `incorrect` verdict is noise.
define i32 @input_wmul(i32 %x, i32 %y) {
  %r = mul i32 %y, %x
  ret i32 %r
}

; forged target: same signature, different semantics (add, not mul).
define i32 @input_wmul(i32 %x, i32 %y) {
  %r = add i32 %x, %y
  ret i32 %r
}

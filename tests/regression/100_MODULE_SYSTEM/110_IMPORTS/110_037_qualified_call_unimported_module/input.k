// Pin: a qualified call into a module that was never imported must refuse
// with KORU211, not reach the emitter — where it used to become a blind
// name-mangled handler call with its string arg demoted to a record field
// (`.@"{{ … }}" = "{{ … }}"`), dying at Zig compile with a nonsense error.
std/io:print.ln("hello")

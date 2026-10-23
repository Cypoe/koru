// Pins `{{ v:d:.N }}` precision formatting crossing the C lane: the
// operand routes to `__koru_*_write_f64_prec(v, N)` → `%.*f`, the
// toFixed spelling the other lanes honor. Output bytes must match the
// zig `{d:.N}` rendering exactly.
import std/io

tor probe { f: f64, g: f64 }
probe = std/io:print.ln("f={{ f:d:.3 }} g={{ g:d:.9 }}")

probe(f: 3.14159, g: 0.1)

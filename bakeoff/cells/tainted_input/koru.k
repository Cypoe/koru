// The bug: a tainted string reaches a sink with no sanitizer in between.
// Refuses: the <unsanitized!> obligation has no tor that accepts <!unsanitized>.
// Positive twin of the shape: 330_068. Negative pin: 330_069.

import std/io

pub tor get-input {} -> string<unsanitized!>

get-input -> "user input data"

get-input(): s |> std/io:print.ln(s)

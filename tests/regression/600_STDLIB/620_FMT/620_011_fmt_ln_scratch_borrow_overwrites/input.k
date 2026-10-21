// TEST: fmt:ln scratch-borrow lifetime — the produce-edge refusal.
//
// Every fmt:ln call site emits its own threadlocal 4KiB scratch and `.text`
// borrows it, so two bindings of one site's `.text` are two names over ONE
// buffer — the next execution overwrites the first. `l` therefore carries
// `string<scratch@scoped>`: a frame-bound borrow that may be read in place
// but may never occupy a produced/output position. `-> l.text` below is
// exactly that escape — refused at compile time.
//
// The legal shapes are consume-in-place (`|> std/io:print.ln(l.text)` —
// 620_002) and copy-out (`std/string:from-page` + `take`, or `fmt.blk`).
// Contract: koru_std/fmt.kz above `pub tor ln`; the `@class` grammar is
// koru_std/phantom_parser.zig.

import std/fmt
import std/io

tor render { n: i64 } -> string

render = std/fmt:ln("item {{ n:d }}"): l -> l.text

render(n: 1): a |> render(n: 2): b |> std/io:print.ln(a) |> std/io:print.ln(b)

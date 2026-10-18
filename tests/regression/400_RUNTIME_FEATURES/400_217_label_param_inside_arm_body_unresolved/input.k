// PINS (red, semantics unruled): a label's param (`n` from `#loop`) is not
// visible inside the arms of the labeled step's own dispatch — `n` in the
// `| err e` arm is NOT reseeding (`@loop(n: …)` is) and the arm body cannot
// see the label's param name. Refused today only by the host:
// `use of undeclared identifier 'n'` in the emitted Zig — same residual
// hole as 400_212 ({{ }} text) and 690_367 (stored {} bodies), which
// KORU108 does not read. If label params are ruled to be visible in arm
// bodies, this flips to a positive pin (n = last seeded value); if not,
// it is owed a koruc diagnostic instead of the host error.
import std/io

pub tor ctr { n: i64 }
| next i64
| done i64

ctr = if(n < 3)
| then => next n + 1
| else => done n

pub tor two {}
| img i64
| err i64

two => img 1

pub tor start {}
start |> std/io:print.ln("go")

start()
|> #loop ctr(n: 0)
    | next x |> @loop(n: x)
    | done d |> two()
        | img t |> std/io:print.ln("img {{ t:d }}")
        | err e |> std/io:print.ln("n is {{ n:d }} {{ e:d }}")

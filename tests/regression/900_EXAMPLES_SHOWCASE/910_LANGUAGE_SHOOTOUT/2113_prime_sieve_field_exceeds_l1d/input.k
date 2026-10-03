// Pins the alternating sweep direction in std/field:mark-multiples. A field
// larger than the core's L1D (2,000,000 odd-only bits = 250 KB, past every L1D
// shipped) turns alternation on: successive markers run forward, backward,
// forward, so each starts on the lines the previous one left resident. Both
// directions of both marker kinds (dense word-mask, sparse byte-scatter) run
// here; the count is only right if every reversed sweep marks exactly the
// multiples its forward twin does. Primes below 4,000,000: 283,146.
import std/io
import std/field

std/field:new(bits: 2000000)
| field f |> for(1..1000)
    ! each i |> std/field:test(f, i): pv |> if(pv == 0)
        | then |> std/field:mark-multiples(f, from: 2 * i * (i + 1), stride: 2 * i + 1, limit: 1999999)
    | done |> std/field:count-zeros(f, lo: 1, hi: 2000000): c |> std/io:print.ln("validated primes: {{ c + 1:d }}") |> std/field:free(f)
| err _ |> _

// TEST: fmt:ln scoped borrow — param-wall laundering is refused.
//
// `.text` carries scratch@scoped. `identity`'s param `data: string`
// declares no scoped acceptance, so the argument `l.text` refuses at the
// call wall (KORU030) before the callee ever binds it — the class follows
// the value through the projection (the carrier `l` is the classed
// binding), and only a param spelled `string<*@scoped>` could take it.
import std/fmt
import std/io

tor identity { data: string } -> string

identity = std/io:print.ln(data): _ -> data

std/fmt:ln("item {{ 1:d }}"): l |> identity(data: l.text): d |> std/io:print.ln(d)

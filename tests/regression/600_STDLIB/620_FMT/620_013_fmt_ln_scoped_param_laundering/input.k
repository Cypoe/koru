// TEST: fmt:ln scoped borrow — param-wall laundering (ASPIRATIONAL, TODO).
//
// `.text` carries scratch@scoped, but projections cross param walls
// unqualified: `identity(data: l.text)` arrives inside `identity` as plain
// `string`, and `-> data` produces an unqualified alias of the scratch borrow
// back to the caller. One indirection defeats the class.
//
// Desired: the class follows the value. With class conferral across
// parameter binding, `data` binds `scratch@scoped` inside `identity` and
// `-> data` refuses KORU030 at the produce edge — same refusal 620_011
// pins for `-> l.text` directly.
//
// Compiles and runs today; MUST_ERROR once conferral lands.
// Residual declared in todo/todo.kz ("fmt-ln-scoped-param-laundering").
import std/fmt
import std/io

tor identity { data: string } -> string

identity = std/io:print.ln(data): _ -> data

std/fmt:ln("item {{ 1:d }}"): l |> identity(data: l.text): d |> std/io:print.ln(d)

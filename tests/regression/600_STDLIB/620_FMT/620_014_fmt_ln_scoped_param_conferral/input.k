import std/fmt
import std/io

// Declared conferral: a param spelled `string<*@scoped>` accepts any
// identity INCLUDING a frame-bound borrow, and binds it scoped inside —
// consume in place is legal, and reissue through a declared `*@scoped`
// output keeps the class on the caller's binding.
tor sink { data: string<*@scoped> } -> i64
sink = std/io:print.ln(data): _ -> 0

tor passthru { data: string<*@scoped> } -> string<*@scoped>
passthru = sink(data): _ -> data

std/fmt:ln("item {{ 1:d }}"): l |> sink(data: l.text): _ |> std/fmt:ln("more {{ 2:d }}"): l2 |> passthru(data: l2.text): d |> std/io:print.ln(d)

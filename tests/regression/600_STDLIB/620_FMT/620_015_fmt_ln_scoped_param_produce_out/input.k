import std/fmt
import std/io

// The other half of declared conferral: `data` binds scoped inside the
// callee, so producing it out through a PLAIN `-> string` output refuses —
// only a declared `-> string<*@scoped>` output may carry the class on.
tor launder { data: string<*@scoped> } -> string
launder = std/io:print.ln(data): _ -> data

std/fmt:ln("item {{ 1:d }}"): l |> launder(data: l.text): d |> std/io:print.ln(d)

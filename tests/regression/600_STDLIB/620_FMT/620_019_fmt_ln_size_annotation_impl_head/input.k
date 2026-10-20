// [size(N)] is a STEP annotation — `name = [x]call` is the impl's slot and
// the parser refuses it, because an impl-level size would describe every
// call inside the impl, not this site. Write [size]name = call for the
// impl itself, or put the call mid-chain.
import std/fmt
import std/io

pub tor big { s: string }
big = [size(16k)]std/fmt:ln("{{ s:s }}"): l
    |> std/io:print.ln(l.text)

big(s: "ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss")

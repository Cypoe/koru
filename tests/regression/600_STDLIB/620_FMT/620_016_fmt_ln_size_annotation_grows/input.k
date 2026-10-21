// fmt:ln [size(16k)] on the call sizes THIS site's threadlocal scratch —
// 5000 output bytes would panic at the 4096 default (620_010). The buffer
// is per-call-site, so the annotation is a step annotation on the call.
import std/fmt
import std/io

pub tor big { s: string }
big = std/io:print.ln("warm")
    |> [size(16k)]std/fmt:ln("{{ s:s }}{{ s:s }}{{ s:s }}{{ s:s }}{{ s:s }}{{ s:s }}{{ s:s }}{{ s:s }}{{ s:s }}{{ s:s }}"): l
    |> std/io:print.ln(l.text)

big(s: "ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss")

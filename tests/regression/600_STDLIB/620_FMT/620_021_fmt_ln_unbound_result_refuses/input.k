// PIN — unbound fmt.ln refuses at the transform with KORU180.
//
// Twin of 620_020 (fmt.blk). `std/fmt:ln("...")` with no `: name` bind used
// to emit the `__LnResult` tagged union (the unbound arm in
// koru_std/fmt.lnzig.kz) — dead surface since the `| line l` branch
// spelling was removed, reaching Zig codegen as a raw type leak. The
// unbound arm now refuses upstream, naming the `: name` bind.
import std/fmt
import std/io

std/fmt:ln("the answer is 42") |> std/io:print.ln("done")

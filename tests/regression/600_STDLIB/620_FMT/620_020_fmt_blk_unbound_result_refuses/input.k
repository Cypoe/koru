// PIN — unbound fmt.blk refuses at the transform with KORU180.
//
// `std/fmt:fmt.blk { ... }` with no `: name` bind used to emit the
// `__BlkResult` tagged union (the `return_binding == null` arm in fmt.kz).
// Nothing could consume that union — `| formatted f` was removed from the
// grammar — so the program reached Zig codegen and died on a raw type error
// (`expected '[]const u8', found '__BlkResult'`). That was the 620_006
// class: a raw Zig type leak where a koru diagnostic belongs. The unbound
// arm now refuses upstream with a message naming the `: name` bind; the
// ln transform (koru_std/fmt.lnzig.kz) is the twin.
import std/fmt
import std/io

const {
    name: "World"
}

std/fmt:fmt.blk {
    Hello, {{ name:s }}!
} |> std/io:print.ln("done")

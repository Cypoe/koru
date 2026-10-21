// ASPIRATIONAL RED — unbound fmt.blk must refuse, not emit the dead union.
//
// `std/fmt:fmt.blk { ... }` with no `: name` bind emits the `__BlkResult`
// tagged union (the `return_binding == null` arm in fmt.kz). Nothing can
// consume that union — `| formatted f` was removed from the grammar — so the
// program reaches Zig codegen and dies on a raw type error
// (`expected '[]const u8', found '__BlkResult'`, plus auto-discharge trying
// to free the union itself). That is the 620_006 class of defect: a raw Zig
// type leak where a koru diagnostic belongs. Green when unbound blk refuses
// at the frontend with a message naming the missing `: name` bind.
import std/fmt
import std/io

const {
    name: "World"
}

std/fmt:fmt.blk {
    Hello, {{ name:s }}!
} |> std/io:print.ln("done")

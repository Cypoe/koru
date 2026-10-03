// PINS: inside a `! query s` arm, a `{{ s.ip:s }}` placeholder in an
// UNQUOTED fmt.blk block must keep its format spec. The row-binding
// rewriter (store.qrewrite refs) walks the block's raw source — there is
// no string literal for expressionMask to hide behind — and before the
// pin it rewrote the `:s` SPEC as the bare row binding `s` (the
// multi-column bare-binding rule mints `__koru_handle_of`). The emitted
// allocPrint then read
//   "{__koru_store_Sessions.__koru_handle_of(__koru_sdix_s_L33)} [{d}]"
// — the handle text as the Zig format specifier on a []const u8 arg —
// and died in Writer.zig: "cannot format slice without a specifier".
// A `:`-glued name is a spec/qualifier position; the row handle is never
// spelled that way (bare refs take `x: s`, with the space).
//
// print.ln's identical placeholder is immune because its source is a
// QUOTED arg — the mask skips literals. fmt.blk blocks are Source text.
// Found building a filter→format→collect pipeline (the LINQ probe).
import std/io
import std/fmt
import std/proto
import std/store

std/proto:string(IpAddress)

std/proto(Session) {
    ip: IpAddress
    score: i64
}

std/store:new(Sessions, capacity: 4) { Session }

std/store:insert(Sessions) { ip: "10.0.0.7", score: 91 }
std/store:insert(Sessions) { ip: "192.168.1.44", score: 12 }
    | row _ |> _
    | full |> _

std/store:query(Sessions)
! query s when s.score > 50 |> std/fmt:fmt.blk { {{ s.ip:s }} [{{ s.score:d }}] }: f |> std/io:print.ln("{{ f:s }}")

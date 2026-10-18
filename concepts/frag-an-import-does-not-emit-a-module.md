---
type: belief
id: frag-an-import-does-not-emit-a-module
provenance: 2026-10-12 — lifting the owned gzip encoder into koru_std/compress.kz; httparena.kz imported the module and referenced koru_std.koru_compress from host lines, and codegen failed "no member named" until a real invocation landed in main.k
ts: 2026-10-12
---

`~import foo` loads a module into the program's AST; it does not put
the module in the emitted binary. In `.runtime_only` mode the visitor
emitter collects a module only when `moduleHasEmittableItems` finds a
tor that survives filtering — and the namespace (`koru_std.koru_foo`)
exists only when the module is collected. Pure-Zig modules — host
lines, `pub fn`s, constants — carry no tor, so they are loaded and
silently absent: a `@import("root").koru_std.koru_foo` reference in a
sibling's Zig body compiles the frontend fine and fails codegen with
"no member named".

Measured 2026-10-12 lifting the gzip encoder into `std/compress`:
the module loaded (`program.ast.json` listed `std.compress`), its
`~pub tor` alone still did not emit the namespace — only a real
`std/compress:gzip(...)` invocation in the entry flow made
`koru_std.koru_compress` materialize. The tor is the honest answer
anyway — a std module with no Koru-level surface has no caller
contract — but the mechanism is worth naming: Zig-level references
do not mark a module used; nothing scans host lines for
`koru_<name>` mentions.

The consequence for every consumer: importing a module for its pub
Zig decls requires one Koru-level call somewhere in the program.
HttpArena solves it with a startup warmup — which is also a real
optimization (the first dynamic Huffman tree is baked before the
first request pays for it). A dedicated "link this module" surface
would be the cleaner tool; today the invocation is it.

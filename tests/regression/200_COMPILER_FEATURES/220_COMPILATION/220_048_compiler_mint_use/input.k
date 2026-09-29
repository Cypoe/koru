// Pins the compiler-mint loop end to end. This file is the mint SOURCE:
// post.sh runs `koruc input.k mint testmint` into a sandboxed
// KORU_MINT_DIR, then drives the whole matrix —
//   * a consumer carrying std/compiler:use(testmint) compiles through the
//     minted binary (Stage A only — no backend regen, no zig build)
//   * hash: passes on the manifest's sha256, refuses a wrong pin
//   * a consumer whose emitted closure differs (an extra comptime-bearing
//     import) is refused with "does not cover this program"
//   * `mint check` exits 0 over the live tree
import std/io

std/io:print.ln("mint-me")

// Pins: a `//` comment trailing a schema field inside a store-new block is
// transparent — it must not reach the emitted Zig. Comment stripping happens
// before emission, so the block's fields and commas survive intact.
import std/io
import std/store

std/store:new(game) {
    score: 0[i64],   // player score
    lives: 3[i64],
}

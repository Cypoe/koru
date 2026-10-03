// An EMPTY source block must capture empty text — not consume the
// declaration that follows it.
//
// The defect this pins: `print.blk {` followed by `}` on the next line
// captures from that `}` THROUGH the next block's closing `}`. The
// following declaration is eaten entirely — it never reaches the AST —
// and the empty block's source is the swallowed text, which then prints
// as garbage. Measured 2026-10-03 on koru/stack's first pass: a service
// decl with an empty `{}` body swallowed the next service decl and
// silently dropped its depends_on edge.
//
// Three print.blk flows must exist in the AST (post.sh counts them), and
// the program prints "first", a blank line (the empty block's empty
// source), then "third".
import std/io

std/io:print.blk {
    first
}

std/io:print.blk {
}

std/io:print.blk {
    third
}

// 690_371 — a store cell read in a `for` iterable lowers, even though the
// `..` range operator puts a dot immediately before the store name.
//
// Pins the member-dot boundary test inside every text rewriter that
// maps `<store>.<field>` onto the cell path: `x.world` must not rewrite
// `world`, so rewriters ask "is the char before a dot?" — but `..` is
// the range operator and `0..world.dd` reads the cell, not a member.
// precededByMemberDot counts the dot run: an odd count is a member dot,
// exactly-two is a range operand. The walk's reach (arg, guard,
// inline_body, expression, branch payload) is unchanged — this is the
// boundary predicate, not a new position.
import std/io
import std/store

std/store:new(world) { dd: 3[i64] }

for(0..@as(usize, @intCast(world.dd)))
! each _ |> std/io:print.ln("x")

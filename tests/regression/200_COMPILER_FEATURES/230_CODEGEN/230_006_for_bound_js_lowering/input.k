// Cross-target FOR lowering of Zig-spelled bound and keep expressions.
// `for|js` (koru_std/control.kz) emits a counting-loop header whose bound is a
// template splice, and `keep:` splices into a `break` guard — the `js_lower`
// filter (template_processor.zig) runs both through lowerKoruExpr, so the
// bound's inline `if (…) … else …` arrives as a ternary and `@as`/`@intCast`
// erase, instead of leaking verbatim Zig inside a JavaScript for-header.
// fire=0 exercises the `else 0` branch of the bound; fire=1 runs the loop far
// enough for `keep` to be evaluated per iteration.
import std/io
import std/store

std/store:new(w) { n: 0[i64] }

pub tor run { fire: i64 }
run = for(0..(if (fire == 1) @as(usize, @intCast(10)) else 0), keep: w.n < 2)
    ! each i |> std/store:stored { w.n: w.n + @as(i64, @intCast(i)) }

run(fire: 0) |> run(fire: 1) |> std/io:print.ln("n={{ w.n:d }}")
